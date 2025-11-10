# Infrastructure as a Service for Data Engineering

[![CI/CD Pipeline](https://github.com/yourusername/iaas-for-data/actions/workflows/ci.yml/badge.svg)](https://github.com/a-chmielewski/iaas-for-data/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready data engineering pipeline demonstrating best practices for cloud infrastructure, automated data ingestion, and modern DevOps workflows. This project showcases infrastructure as code (IaC), containerization, and serverless architecture on Google Cloud Platform.

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Technologies](#-technologies)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Setup & Deployment](#-setup--deployment)
- [Usage](#-usage)
- [Infrastructure Details](#-infrastructure-details)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Monitoring & Observability](#-monitoring--observability)
- [Cost Optimization](#-cost-optimization)
- [Security](#-security)
- [Future Enhancements](#-future-enhancements)
- [Contributing](#-contributing)
- [License](#-license)

## 🎯 Project Overview

This project implements an automated daily pipeline that:

1. **Ingests** foreign exchange (FX) rates from the European Central Bank (ECB) public API
2. **Stores** raw data in Google Cloud Storage with automatic lifecycle management
3. **Transforms** wide-format CSV data into normalized long-format structure
4. **Loads** data into BigQuery with partitioning for optimal query performance
5. **Schedules** daily execution using Cloud Scheduler
6. **Monitors** execution through Cloud Run logging and metrics

The infrastructure is fully automated using Terraform, containerized with Docker, and deployed via GitHub Actions CI/CD pipeline.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions CI/CD                      │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────────────┐  │
│  │ Checkout │→ │ Build Docker │→ │ Terraform Apply (IaC)   │  │
│  └──────────┘  └──────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ Deploys to GCP
┌─────────────────────────────────────────────────────────────────┐
│                      Google Cloud Platform                       │
│                                                                  │
│  ┌─────────────────┐                                            │
│  │ Cloud Scheduler │ (Daily 05:00 UTC)                         │
│  └────────┬────────┘                                            │
│           │ POST Request (OIDC Auth)                            │
│           ↓                                                      │
│  ┌─────────────────┐         ┌──────────────────┐              │
│  │   Cloud Run     │         │ Service Accounts │              │
│  │  (Flask App)    │←────────│  (Least Privilege)│              │
│  └────┬────────────┘         └──────────────────┘              │
│       │                                                          │
│       ├→ 1. Fetch CSV from ECB API                              │
│       │                                                          │
│       ├→ 2. ┌─────────────────────────┐                        │
│       │    │  Cloud Storage Bucket    │                         │
│       │    │  ├─ raw/dt=YYYY-MM-DD/   │                        │
│       │    │  │  ├─ source.csv         │                        │
│       │    │  │  └─ normalized.csv     │                        │
│       │    │  └─ (30-day lifecycle)    │                        │
│       │    └─────────────────────────┘                          │
│       │                                                          │
│       └→ 3. ┌─────────────────────────┐                        │
│            │     BigQuery Dataset      │                         │
│            │  ┌──────────────────────┐│                         │
│            │  │ raw_fx_rates (Table) ││                         │
│            │  │ - Date partitioned   ││                         │
│            │  │ - Normalized schema  ││                         │
│            │  │ - Append-only        ││                         │
│            │  └──────────────────────┘│                         │
│            └─────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Trigger**: Cloud Scheduler invokes Cloud Run service daily at 05:00 UTC
2. **Fetch**: Application downloads FX rates CSV from ECB API
3. **Store Raw**: Original CSV uploaded to GCS with date partitioning
4. **Transform**: Wide-format CSV transformed to long-format (date, currency, rate)
5. **Load**: Normalized data loaded into BigQuery partitioned table
6. **Respond**: HTTP 200 response with load job details

## 🛠️ Technologies

### Infrastructure & Cloud
- **Google Cloud Platform (GCP)**: Primary cloud provider
  - Cloud Run (v2): Serverless container platform
  - Cloud Storage: Object storage for raw data
  - BigQuery: Data warehouse for analytics
  - Cloud Scheduler: Cron-based job scheduler
  - IAM: Service accounts with least-privilege access
- **Terraform (v1.7+)**: Infrastructure as Code
- **Docker**: Container runtime

### Application
- **Python 3.11**: Programming language
- **Flask 3.0**: Web framework
- **Pandas 2.2**: Data transformation
- **Google Cloud Client Libraries**: 
  - `google-cloud-storage`: GCS operations
  - `google-cloud-bigquery`: BigQuery operations
- **Gunicorn**: WSGI HTTP Server

### CI/CD & DevOps
- **GitHub Actions**: CI/CD automation
- **Workload Identity Federation**: Secure GCP authentication
- **Docker**: Container image building

## ✨ Features

### Infrastructure Features
- ✅ **Fully Automated Infrastructure**: 100% Infrastructure as Code using Terraform
- ✅ **Modular Design**: Reusable Terraform modules for each service
- ✅ **Multi-Environment Support**: Dev/Prod environment configurations
- ✅ **Least-Privilege IAM**: Separate service accounts with minimal permissions
- ✅ **Serverless Architecture**: Zero maintenance, auto-scaling compute
- ✅ **Cost Optimized**: Scale-to-zero, lifecycle policies, resource limits

### Data Pipeline Features
- ✅ **Automated Daily Ingestion**: Hands-free scheduled execution
- ✅ **Data Versioning**: Date-partitioned raw data storage
- ✅ **Data Transformation**: Wide-to-long format normalization
- ✅ **Incremental Loading**: Append-only BigQuery writes
- ✅ **Partitioned Storage**: Day-partitioned BigQuery table for query optimization
- ✅ **Data Lifecycle Management**: Automatic 30-day GCS cleanup

### DevOps Features
- ✅ **CI/CD Pipeline**: Automated build, test, and deployment
- ✅ **Container Security**: Slim Python base image, non-root user
- ✅ **OIDC Authentication**: Keyless GitHub-to-GCP authentication
- ✅ **Health Checks**: `/healthz` endpoint for monitoring
- ✅ **Structured Logging**: JSON logs for Cloud Logging integration

## 📁 Project Structure

```
iaas-for-data/
├── app/                          # Application code
│   ├── Dockerfile                # Container image definition
│   ├── main.py                   # Flask application (ingest logic)
│   └── requirements.txt          # Python dependencies
│
├── infra/                        # Terraform infrastructure
│   ├── main.tf                   # Root module (orchestrates all modules)
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── providers.tf              # GCP provider configuration
│   ├── versions.tf               # Terraform version constraints
│   │
│   ├── envs/                     # Environment-specific configs
│   │   ├── dev/
│   │   │   └── terraform.tfvars  # Dev environment variables
│   │   └── prod/
│   │       └── terraform.tfvars  # Prod environment variables
│   │
│   └── modules/                  # Reusable Terraform modules
│       ├── iam/                  # Service account creation
│       │   └── main.tf
│       ├── storage_bucket/       # GCS bucket with lifecycle
│       │   └── main.tf
│       ├── bigquery/             # Dataset and table creation
│       │   ├── main.tf
│       │   └── schemas/
│       │       └── raw_fx_rates.json
│       ├── cloud_run/            # Serverless container deployment
│       │   └── main.tf
│       └── scheduler/            # Cron job configuration
│           └── main.tf
│
├── .github/
│   └── workflows/
│       └── ci.yml                # GitHub Actions CI/CD pipeline
│
├── docs/                         # Documentation assets
│   └── bigquery_results.png      # Sample query results
│
├── README.md                     # This file
└── SECURITY.md                   # Security policies and procedures
```

## 📦 Prerequisites

### Required Tools
- **Terraform** >= 1.7.0
- **Docker** >= 20.10
- **gcloud CLI** >= 450.0.0
- **Git** >= 2.30

### GCP Requirements
- GCP Project with billing enabled
- APIs enabled:
  - Cloud Run API
  - Cloud Scheduler API
  - Cloud Storage API
  - BigQuery API
  - Artifact Registry API
  - IAM API
- Artifact Registry repository: `app-images`
- (Optional) GitHub OIDC Workload Identity Pool for CI/CD

## 🚀 Setup & Deployment

### 1. Clone Repository

```bash
git clone https://github.com/a-chmielewski/iaas-for-data.git
cd iaas-for-data
```

### 2. Configure GCP Project

```bash
# Set your GCP project
export GCP_PROJECT="your-project-id"
gcloud config set project $GCP_PROJECT

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  storage.googleapis.com \
  bigquery.googleapis.com \
  artifactregistry.googleapis.com
```

### 3. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create app-images \
  --repository-format=docker \
  --location=us-central1 \
  --description="Application container images"
```

### 4. Build & Push Container Image

```bash
# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push image
export IMAGE_REF="us-central1-docker.pkg.dev/${GCP_PROJECT}/app-images/ingest:latest"
docker build -t $IMAGE_REF ./app
docker push $IMAGE_REF
```

### 5. Deploy Infrastructure with Terraform

```bash
cd infra

# Initialize Terraform
terraform init

# Review planned changes
terraform plan \
  -var="project_id=${GCP_PROJECT}" \
  -var="region=us-central1" \
  -var="image_ref=${IMAGE_REF}" \
  -var="source_url=https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.csv"

# Apply infrastructure
terraform apply \
  -var="project_id=${GCP_PROJECT}" \
  -var="region=us-central1" \
  -var="image_ref=${IMAGE_REF}" \
  -var="source_url=https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.csv"
```

### 6. Verify Deployment

```bash
# Get Cloud Run URL
export RUN_URL=$(terraform output -raw run_url)

# Manual test trigger
curl -X POST $RUN_URL

# Check BigQuery for data
bq query --use_legacy_sql=false \
  'SELECT date, currency, rate 
   FROM `analytics.raw_fx_rates` 
   LIMIT 10'
```

## 💻 Usage

### Manual Trigger

Trigger the ingestion manually via HTTP POST:

```bash
# Get service URL
gcloud run services describe ingest \
  --region=us-central1 \
  --format='value(status.url)'

# Trigger with authentication
curl -X POST $(gcloud run services describe ingest \
  --region=us-central1 \
  --format='value(status.url)') \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```

### Query BigQuery Data

```sql
-- Recent FX rates
SELECT 
  date,
  currency,
  rate,
  ingestion_date
FROM `analytics.raw_fx_rates`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY date DESC, currency;

-- Average rate by currency (last 30 days)
SELECT 
  currency,
  AVG(rate) as avg_rate,
  MIN(rate) as min_rate,
  MAX(rate) as max_rate,
  COUNT(*) as data_points
FROM `analytics.raw_fx_rates`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY currency
ORDER BY currency;
```

### View Cloud Storage Files

```bash
# List raw files
gsutil ls -r gs://$(terraform output -raw bucket_name)/raw/

# Download a specific file
gsutil cp gs://$(terraform output -raw bucket_name)/raw/dt=2025-11-10/normalized.csv .
```

### View Logs

```bash
# Stream Cloud Run logs
gcloud run services logs read ingest \
  --region=us-central1 \
  --limit=50

# View Scheduler logs
gcloud logging read "resource.type=cloud_scheduler_job" \
  --limit=50 \
  --format=json
```

## 🏛️ Infrastructure Details

### Service Accounts & IAM

Two service accounts with least-privilege access:

1. **ingest-runner** (Cloud Run runtime)
   - `roles/bigquery.jobUser`: Create BigQuery jobs
   - `roles/bigquery.dataEditor`: Write to `analytics` dataset
   - `roles/storage.objectAdmin`: Write to data bucket

2. **scheduler-invoker** (Cloud Scheduler)
   - `roles/run.invoker`: Invoke Cloud Run service

### Cloud Run Configuration

- **Scaling**: 0-1 instances (scale to zero for cost optimization)
- **CPU**: 1 vCPU
- **Memory**: 1 GiB
- **Timeout**: 60 seconds
- **Ingress**: All traffic (change to `INGRESS_TRAFFIC_INTERNAL` for production)
- **Concurrency**: 1 request per instance (gunicorn with 2 threads)

### BigQuery Table Schema

```json
{
  "fields": [
    {"name": "date", "type": "DATE", "mode": "NULLABLE"},
    {"name": "currency", "type": "STRING", "mode": "NULLABLE"},
    {"name": "rate", "type": "FLOAT", "mode": "NULLABLE"},
    {"name": "ingestion_date", "type": "DATE", "mode": "REQUIRED"}
  ]
}
```

**Partitioning**: Day-partitioned on `ingestion_date` for cost-effective queries.

### Cloud Storage Lifecycle

- **Retention**: 30 days
- **Action**: Automatic deletion after 30 days
- **Purpose**: Maintain audit trail while controlling costs

## 🔄 CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`) automates:

1. **Checkout**: Clone repository
2. **Terraform Setup**: Install Terraform v1.7.5
3. **GCP Authentication**: OIDC-based workload identity (no keys!)
4. **Docker Build & Push**: Build and push image to Artifact Registry
5. **Terraform Deploy**: 
   - `terraform fmt -check`: Validate formatting
   - `terraform validate`: Validate configuration
   - `terraform plan`: Preview changes
   - `terraform apply`: Deploy infrastructure

### Required GitHub Secrets

- `GCP_WORKLOAD_IDENTITY_PROVIDER`: Workload Identity Pool provider
- `GCP_CI_SA_EMAIL`: CI service account email

### Required GitHub Variables

- `GCP_PROJECT`: GCP project ID
- `GCP_REGION`: Deployment region (e.g., `us-central1`)

### Setting Up Workload Identity Federation

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-actions" \
  --project="${GCP_PROJECT}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${GCP_PROJECT}" \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create service account for CI
gcloud iam service-accounts create github-actions-ci \
  --display-name="GitHub Actions CI"

# Grant required permissions
gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member="serviceAccount:github-actions-ci@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Allow GitHub repo to impersonate service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-ci@${GCP_PROJECT}.iam.gserviceaccount.com \
  --project="${GCP_PROJECT}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/yourusername/iaas-for-data"
```

## 📊 Monitoring & Observability

### Cloud Run Metrics

Available in GCP Console > Cloud Run > ingest:
- Request count
- Request latency (p50, p95, p99)
- Instance count
- CPU/Memory utilization
- Error rate

### Cloud Logging

```bash
# View application logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ingest" \
  --limit=100 \
  --format=json

# Filter for errors
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit=50
```

### BigQuery Monitoring

```sql
-- Data freshness check
SELECT 
  MAX(ingestion_date) as last_ingestion,
  DATE_DIFF(CURRENT_DATE(), MAX(ingestion_date), DAY) as days_since_last_load
FROM `analytics.raw_fx_rates`;

-- Row count by ingestion date
SELECT 
  ingestion_date,
  COUNT(*) as row_count
FROM `analytics.raw_fx_rates`
GROUP BY ingestion_date
ORDER BY ingestion_date DESC
LIMIT 30;
```

### Alerting (Future Enhancement)

Consider setting up alerts for:
- Cloud Run error rate > threshold
- Scheduler job failures
- Data freshness > 1 day old
- BigQuery storage costs

## 💰 Cost Optimization

### Estimated Monthly Costs (USD)

| Service | Usage | Cost |
|---------|-------|------|
| Cloud Run | ~30 invocations/month, <1min each | $0.00 (free tier) |
| Cloud Scheduler | 1 job | $0.10 |
| Cloud Storage | <1 GB, 30-day retention | $0.02 |
| BigQuery | Storage: <10 GB, Queries: minimal | $0.20 |
| **Total** | | **~$0.32/month** |

### Cost Optimization Strategies

1. **Scale to Zero**: Cloud Run instances automatically terminate when idle
2. **Lifecycle Policies**: GCS objects auto-delete after 30 days
3. **Table Partitioning**: BigQuery partitions reduce query costs
4. **Resource Limits**: CPU/memory caps prevent runaway costs
5. **Minimal Query Frequency**: Daily schedule, not continuous
6. **Free Tier Usage**: Most services stay within GCP free tier

## 🔒 Security

See [SECURITY.md](SECURITY.md) for detailed security policies.

### Security Highlights

- ✅ **Least-Privilege IAM**: Separate service accounts with minimal permissions
- ✅ **No API Keys**: Workload Identity Federation for CI/CD (OIDC)
- ✅ **Container Security**: Non-root user, minimal base image
- ✅ **Network Security**: Private service accounts, no public IPs
- ✅ **Secrets Management**: Environment variables via Cloud Run configuration
- ✅ **Audit Logging**: All API calls logged to Cloud Logging
- ✅ **Ingress Controls**: Can restrict to internal traffic only

### Security Best Practices Applied

1. **Infrastructure as Code**: All resources version-controlled and auditable
2. **Immutable Infrastructure**: Container-based deployments
3. **Automated Patching**: Base image updates via CI/CD
4. **Dependency Scanning**: Requirements pinned with versions
5. **Network Isolation**: Services communicate via internal GCP networking

## 🚧 Future Enhancements

### Immediate Improvements
- [ ] Add data quality checks (Great Expectations)
- [ ] Implement retry logic with exponential backoff
- [ ] Add comprehensive unit and integration tests
- [ ] Create Terraform remote state (GCS backend)
- [ ] Add Cloud Monitoring alerts

### Advanced Features
- [ ] Multi-source data ingestion (additional APIs)
- [ ] dbt transformations for analytics
- [ ] Apache Airflow orchestration
- [ ] Streaming ingestion via Pub/Sub
- [ ] Data cataloging with Dataplex
- [ ] ML model training on historical FX data

### DevOps Improvements
- [ ] Terraform workspace management
- [ ] Blue-green deployments
- [ ] Canary releases
- [ ] Load testing with Locust
- [ ] Cost monitoring dashboards

## 🤝 Contributing

This is a portfolio project, but suggestions are welcome! If you notice improvements:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-improvement`)
3. Commit your changes (`git commit -m 'Add amazing improvement'`)
4. Push to the branch (`git push origin feature/amazing-improvement`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Your Name**
- GitHub: [@a-chmielewski](https://github.com/a-chmielewski)
- LinkedIn: [a-chmielewski](https://www.linkedin.com/in/a-chmielewski/)
- Portfolio: [a-chmielewski.github.io](https://a-chmielewski.github.io/)

## 🙏 Acknowledgments

- European Central Bank for providing free FX rate data
- Google Cloud Platform for generous free tier
- Terraform for excellent IaC tooling
- Open source community for amazing libraries

---

**Note**: This project is for demonstration purposes. For production use, consider additional security hardening, monitoring, and data governance controls.

