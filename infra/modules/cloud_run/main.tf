variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "image_ref" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "bq_dataset" {
  type = string
}

# Use SA from IAM module by data or pass it in; here we create a small SA if not passed
resource "google_service_account" "ingest_runner" {
  account_id   = "ingest-runner"
  display_name = "Ingest Runner"
}

resource "google_cloud_run_v2_service" "ingest" {
  name     = "ingest"
  location = var.region

  template {
    service_account = google_service_account.ingest_runner.email
    containers {
      image = var.image_ref

      env {
        name  = "BUCKET"
        value = var.bucket_name
      }

      env {
        name  = "BQ_DS"
        value = var.bq_dataset
      }

      env {
        name  = "BQ_TBL"
        value = "raw_fx_rates"
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    timeout = "60s"
  }

  ingress = "ingress internal-and-cloud-load-balancing" # not public
}

# Least-privilege for the runtime SA on GCS & BigQuery
resource "google_project_iam_member" "ingest_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingest_runner.email}"
}

resource "google_bigquery_dataset_iam_member" "ingest_bq_editor" {
  dataset_id = var.bq_dataset
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.ingest_runner.email}"
}

resource "google_storage_bucket_iam_member" "ingest_gcs" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingest_runner.email}"
}

output "url" {
  value = google_cloud_run_v2_service.ingest.uri
}

output "sa_email" {
  value = google_service_account.ingest_runner.email
}