import os
import io
import datetime as dt
import pandas as pd
import requests
from flask import Flask, request, jsonify
from google.cloud import storage, bigquery


BUCKET = os.environ.get("BUCKET")
BQ_DS = os.environ.get("BQ_DS")
BQ_TBL = os.environ.get("BQ_TBL", "raw_fx_rates")
# If SOURCE_URL env is not set, we default to ECB historical CSV
SOURCE_URL = os.environ.get(
    "SOURCE_URL", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.csv"
)


app = Flask(__name__)


@app.post("/")
def ingest():
    today = dt.date.today().isoformat()
    # 1) Download source
    r = requests.get(SOURCE_URL, timeout=30)
    r.raise_for_status()

    # 2) Parse + normalize minimal schema
    # ECB CSV is wide format; to keep demo consistent, we store raw file and also a normalized 3-col form
    raw_bytes = r.content

    # Save raw to GCS
    blob_path = f"raw/dt={today}/source.csv"
    storage_client = storage.Client()
    bucket = storage_client.bucket(BUCKET)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(raw_bytes, content_type="text/csv")

    # Normalize (date, currency, rate)
    df_wide = pd.read_csv(io.BytesIO(raw_bytes))
    # The first column is Date, others are currencies
    df_long = df_wide.melt(
        id_vars=[df_wide.columns[0]], var_name="currency", value_name="rate"
    )
    df_long.rename(columns={df_wide.columns[0]: "date"}, inplace=True)
    df_long["ingestion_date"] = pd.to_datetime(today).date()

    # Write normalized CSV to GCS (optional but nice for auditing)
    norm_csv = df_long.to_csv(index=False)
    norm_path = f"raw/dt={today}/normalized.csv"
    bucket.blob(norm_path).upload_from_string(norm_csv, content_type="text/csv")

    # 3) Load into BigQuery via LOAD job
    bq = bigquery.Client()
    table_id = f"{bq.project}.{BQ_DS}.{BQ_TBL}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=False,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField("date", "DATE", mode="NULLABLE"),
            bigquery.SchemaField("currency", "STRING", mode="NULLABLE"),
            bigquery.SchemaField("rate", "FLOAT", mode="NULLABLE"),
            bigquery.SchemaField("ingestion_date", "DATE", mode="REQUIRED"),
        ],
    )

    uri = f"gs://{BUCKET}/{norm_path}"
    load_job = bq.load_table_from_uri(uri, table_id, job_config=job_config)
    load_job.result()

    return jsonify({"status": "ok", "loaded_uri": uri, "table": table_id})


# Health check
@app.get("/healthz")
def healthz():
    return "ok", 200
