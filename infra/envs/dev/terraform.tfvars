project_id = "iaas-for-data"
region = "us-central1"
bq_location = "US"
# Update after you build/push the container image (step 6)
image_ref = "us-central1-docker.pkg.dev/iaas-for-data/app-images/ingest:dev"
source_url = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.csv"