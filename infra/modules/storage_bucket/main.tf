variable "project_id" {
  type = string
}

resource "google_storage_bucket" "data" {
  name                        = "${var.project_id}-data"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

output "name" {
  value = google_storage_bucket.data.name
}