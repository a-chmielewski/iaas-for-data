project_id = "my-free-tier-demo"
region = "us-central1"
bq_location = "US"
# Update after you build/push the container image (step 6)
image_ref = "us-central1-docker.pkg.dev/my-free-tier-demo/app-images/ingest:latest"
source_url = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.csv"