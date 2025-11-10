variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id = "analytics"
  location   = var.location
}

resource "google_bigquery_table" "raw_fx_rates" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "raw_fx_rates"

  time_partitioning {
    type  = "DAY"
    field = "ingestion_date" # present in schema below
  }

  schema = file("${path.module}/schemas/raw_fx_rates.json")
}

output "dataset_id" {
  value = google_bigquery_dataset.analytics.dataset_id
}