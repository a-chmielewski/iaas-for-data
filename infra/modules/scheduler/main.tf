variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "run_url" {
  type = string
}

variable "scheduler_sa" {
  type = string
}

# Allow scheduler SA to invoke Cloud Run service (run.invoker) at the service-level
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  name     = "ingest"
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.scheduler_sa}"
}

# Create a daily job at 05:00 UTC (06:00 CET during standard time)
resource "google_cloud_scheduler_job" "daily_ingest" {
  name      = "daily-ingest"
  region    = var.region
  schedule  = "0 5 * * *"
  time_zone = "UTC"

  http_target {
    uri         = var.run_url
    http_method = "POST"

    oidc_token {
      service_account_email = var.scheduler_sa
      audience             = var.run_url
    }

    body = base64encode("{}")
  }
}