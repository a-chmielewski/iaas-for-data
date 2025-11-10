variable "project_id" {
  type = string
}

# Service accounts (if you didn’t precreate them, create here)
resource "google_service_account" "ingest_runner" {
  account_id   = "ingest-runner"
  display_name = "Ingest Runner"
}

resource "google_service_account" "scheduler_invoker" {
  account_id   = "scheduler-invoker"
  display_name = "Scheduler Invoker"
}

# Least-privilege roles will be bound in other modules where scopes are known.

output "ingest_sa_email" {
  value = google_service_account.ingest_runner.email
}

output "scheduler_sa_email" {
  value = google_service_account.scheduler_invoker.email
}