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

variable "service_account_email" {
  type = string
}

resource "google_cloud_run_v2_service" "ingest" {
  name     = "ingest"
  location = var.region

  template {
    service_account = var.service_account_email

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

      resources {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"   # was 512Mi
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    timeout = "60s"
  }

  ingress = "INGRESS_TRAFFIC_ALL"
}

# Least-privilege for the runtime SA on GCS & BigQuery
resource "google_project_iam_member" "ingest_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_bigquery_dataset_iam_member" "ingest_bq_editor" {
  dataset_id = var.bq_dataset
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "ingest_gcs" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

output "url" {
  value = google_cloud_run_v2_service.ingest.uri
}

output "sa_email" {
  value = var.service_account_email
}