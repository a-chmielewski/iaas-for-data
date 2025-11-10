# Modules commented out until implemented
module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
}

module "storage" {
  source     = "./modules/storage_bucket"
  project_id = var.project_id
}

module "bigquery" {
  source     = "./modules/bigquery"
  project_id = var.project_id
  location   = var.bq_location
}

module "cloud_run" {
  source                = "./modules/cloud_run"
  project_id            = var.project_id
  region                = var.region
  image_ref             = var.image_ref
  bucket_name           = module.storage.name
  bq_dataset            = module.bigquery.dataset_id
  service_account_email = module.iam.ingest_sa_email
}

module "scheduler" {
  source       = "./modules/scheduler"
  project_id   = var.project_id
  region       = var.region
  run_url      = module.cloud_run.url
  scheduler_sa = module.iam.scheduler_sa_email
}
