# Security Policy

## Overview

This document outlines the security architecture, policies, and procedures for the **IaaS for Data Engineering** project. Security is a core principle in this infrastructure, implementing defense-in-depth strategies, least-privilege access controls, and modern cloud security best practices.

## Table of Contents

- [Security Architecture](#security-architecture)
- [Threat Model](#threat-model)
- [Security Controls](#security-controls)
- [IAM & Access Control](#iam--access-control)
- [Network Security](#network-security)
- [Data Security](#data-security)
- [Container Security](#container-security)
- [Secrets Management](#secrets-management)
- [Compliance & Auditing](#compliance--auditing)
- [Vulnerability Management](#vulnerability-management)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)
- [Reporting Security Issues](#reporting-security-issues)

---

## Security Architecture

### Principles

This project follows these core security principles:

1. **Least Privilege**: Every service account has only the minimum permissions required
2. **Defense in Depth**: Multiple layers of security controls
3. **Secure by Default**: All resources created with security best practices
4. **Immutable Infrastructure**: Infrastructure changes via code, not manual modifications
5. **Zero Trust**: No implicit trust; verify every request
6. **Auditability**: All actions logged and traceable

### Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 7: Compliance & Governance                            │
│  - Audit Logging, Policy Enforcement, Compliance Monitoring │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: Application Security                               │
│  - Input Validation, Error Handling, Secure Dependencies    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Container Security                                 │
│  - Minimal Base Image, Non-root User, Image Scanning        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Runtime Security                                   │
│  - Cloud Run Security, Resource Limits, Timeout Controls    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Identity & Access Management                       │
│  - Service Accounts, IAM Roles, OIDC Authentication         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Network Security                                   │
│  - Ingress Controls, Private Networking, VPC (if enabled)   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Data Security                                      │
│  - Encryption at Rest, Encryption in Transit, Data Lifecycle│
└─────────────────────────────────────────────────────────────┘
```

---

## Threat Model

### Assets

1. **FX Rate Data**: Ingested from public ECB API (low sensitivity)
2. **Infrastructure Configuration**: Terraform state (high sensitivity)
3. **Service Accounts**: Identity credentials (critical)
4. **Application Code**: Flask application and logic (medium sensitivity)
5. **GCP Resources**: Compute, storage, and data warehouse resources

### Threats & Mitigations

| Threat | Impact | Likelihood | Mitigation |
|--------|--------|------------|------------|
| **Unauthorized Cloud Run Access** | High | Medium | OIDC authentication, service account verification |
| **Data Tampering in BigQuery** | Medium | Low | Append-only writes, audit logs, IAM controls |
| **Container Vulnerability Exploitation** | High | Medium | Regular image updates, minimal base image, non-root user |
| **Credential Theft** | Critical | Low | No long-lived keys, Workload Identity Federation |
| **Excessive IAM Permissions** | High | Medium | Least-privilege roles, regular IAM audits |
| **Supply Chain Attack** | High | Low | Pinned dependencies, container image scanning |
| **DDoS/Resource Exhaustion** | Medium | Medium | Rate limiting, timeout controls, cost alerts |
| **Data Exfiltration** | Low | Low | Data classification (public data), VPC controls |

---

## Security Controls

### Implemented Controls

#### 1. Identity & Access Management (IAM)

**Service Account Separation**

Two dedicated service accounts with minimal permissions:

```hcl
# Cloud Run runtime service account
resource "google_service_account" "ingest_runner" {
  account_id   = "ingest-runner"
  display_name = "Ingest Runner"
}

# Cloud Scheduler invoker service account
resource "google_service_account" "scheduler_invoker" {
  account_id   = "scheduler-invoker"
  display_name = "Scheduler Invoker"
}
```

**Least-Privilege Role Assignments**

```
ingest-runner:
  - roles/bigquery.jobUser (project-level)
  - roles/bigquery.dataEditor (analytics dataset only)
  - roles/storage.objectAdmin (data bucket only)

scheduler-invoker:
  - roles/run.invoker (ingest service only)
```

**No Long-Lived Credentials**
- No service account keys exported
- Workload Identity Federation for GitHub Actions
- OIDC tokens for service-to-service authentication

#### 2. Network Security

**Ingress Controls**

```hcl
resource "google_cloud_run_v2_service" "ingest" {
  ingress = "INGRESS_TRAFFIC_ALL"  # Change to INGRESS_TRAFFIC_INTERNAL for production
}
```

**Recommendations for Production**:
- Set `ingress = "INGRESS_TRAFFIC_INTERNAL"` to restrict access to GCP services only
- Use Cloud Load Balancer with Cloud Armor for DDoS protection
- Implement VPC Service Controls for data perimeter

**TLS/HTTPS**
- All Cloud Run services served over HTTPS (enforced by GCP)
- All external API calls use HTTPS
- No plaintext communication

#### 3. Data Security

**Encryption at Rest**
- BigQuery: AES-256 encryption (Google-managed keys)
- Cloud Storage: AES-256 encryption (Google-managed keys)
- For enhanced security, consider Customer-Managed Encryption Keys (CMEK)

**Encryption in Transit**
- All data transfer uses TLS 1.2+
- Internal GCP service communication encrypted by default

**Data Lifecycle Management**

```hcl
lifecycle_rule {
  condition {
    age = 30  # Automatic deletion after 30 days
  }
  action {
    type = "Delete"
  }
}
```

**Data Classification**
- Current data: Public (ECB FX rates)
- Sensitivity: Low
- No PII or sensitive information processed

#### 4. Container Security

**Minimal Base Image**

```dockerfile
FROM python:3.11-slim  # Minimal Debian-based image
```

**Best Practices**:
- Use slim variant (smaller attack surface)
- Pin specific Python version (reproducible builds)
- Multi-stage builds (if needed for compilation)

**Non-Root User** (Enhancement Needed)

Currently runs as root. **Recommended improvement**:

```dockerfile
# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser
```

**Dependency Security**
- All dependencies pinned to specific versions
- Regular updates via Dependabot (recommended)
- No wildcard version specifications

```
flask==3.0.0
gunicorn==21.2.0
google-cloud-storage==2.18.2
google-cloud-bigquery==3.25.0
pandas==2.2.3
requests==2.32.3
```

**Image Scanning** (Enhancement Needed)

Add to CI/CD pipeline:

```yaml
- name: Scan container image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.image.outputs.image_ref }}
    format: 'sarif'
    output: 'trivy-results.sarif'
```

#### 5. Application Security

**Input Validation**
- All external inputs validated
- Timeout on external API calls (30s)
- HTTP status checks on responses

```python
r = requests.get(SOURCE_URL, timeout=30)
r.raise_for_status()  # Validates HTTP 200
```

**Error Handling**
- Graceful error handling
- No sensitive information in error messages
- Proper HTTP status codes returned

**Dependency Vulnerabilities**

Run regular security audits:

```bash
pip install safety
safety check -r requirements.txt
```

**Environment Variable Injection**

All configuration via environment variables (no hardcoded secrets):

```python
BUCKET = os.environ.get("BUCKET")
BQ_DS = os.environ.get("BQ_DS")
BQ_TBL = os.environ.get("BQ_TBL", "raw_fx_rates")
SOURCE_URL = os.environ.get("SOURCE_URL", "<default_url>")
```

#### 6. CI/CD Security

**Workload Identity Federation (No Keys!)**

```yaml
- name: Auth to GCP via OIDC
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_CI_SA_EMAIL }}
```

**GitHub Actions Security**
- OIDC-based authentication (no service account keys)
- Secrets stored in GitHub Secrets (encrypted)
- Minimal CI service account permissions
- Branch protection rules (recommended)

**Terraform Security**
- State file contains sensitive data (keep secure)
- Use remote state with encryption (recommended)
- State locking to prevent concurrent modifications

---

## IAM & Access Control

### Service Account Permissions Matrix

| Service Account | Resource | Role | Justification |
|----------------|----------|------|---------------|
| `ingest-runner` | Project | `roles/bigquery.jobUser` | Create BigQuery load jobs |
| `ingest-runner` | Dataset: analytics | `roles/bigquery.dataEditor` | Write to raw_fx_rates table |
| `ingest-runner` | Bucket: {project}-data | `roles/storage.objectAdmin` | Upload raw and normalized CSV files |
| `scheduler-invoker` | Cloud Run: ingest | `roles/run.invoker` | Trigger daily ingestion |

### IAM Best Practices

1. **No Owner/Editor Roles**: Only use granular, predefined roles
2. **Resource-Level Bindings**: Grant access at resource level, not project level when possible
3. **Regular Audits**: Review IAM bindings quarterly
4. **Service Account Keys**: Never export or use service account keys
5. **User Access**: Use groups for user access management

### IAM Audit Commands

```bash
# List all IAM bindings for project
gcloud projects get-iam-policy ${GCP_PROJECT} --format=json

# List service accounts
gcloud iam service-accounts list

# Check specific service account permissions
gcloud projects get-iam-policy ${GCP_PROJECT} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:ingest-runner@${GCP_PROJECT}.iam.gserviceaccount.com"
```

---

## Network Security

### Current Configuration

- **Ingress**: `INGRESS_TRAFFIC_ALL` (all traffic allowed)
- **VPC**: Not configured (using default GCP networking)
- **Firewall**: GCP default firewall rules apply

### Production Hardening Recommendations

#### 1. Restrict Ingress to Internal Traffic

```hcl
resource "google_cloud_run_v2_service" "ingest" {
  ingress = "INGRESS_TRAFFIC_INTERNAL"  # Only GCP services
}
```

This prevents external internet access to Cloud Run service.

#### 2. Implement VPC Service Controls

Create a service perimeter around sensitive resources:

```bash
gcloud access-context-manager perimeters create data_perimeter \
  --title="Data Engineering Perimeter" \
  --resources=projects/${PROJECT_NUMBER} \
  --restricted-services=storage.googleapis.com,bigquery.googleapis.com \
  --policy=${POLICY_ID}
```

#### 3. Cloud Armor (DDoS Protection)

If external access is required, add Cloud Load Balancer with Cloud Armor:

```hcl
resource "google_compute_security_policy" "policy" {
  name = "ingest-security-policy"

  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }
}
```

#### 4. Private Google Access

Ensure services can access Google APIs without public IPs:

```bash
gcloud compute networks subnets update default \
  --region=us-central1 \
  --enable-private-ip-google-access
```

---

## Data Security

### Data Classification

| Data Type | Classification | Sensitivity | Encryption | Retention |
|-----------|---------------|-------------|------------|-----------|
| ECB FX Rates | Public | Low | AES-256 at rest | 30 days (GCS), indefinite (BQ) |
| Infrastructure Config | Confidential | High | Git encryption | Indefinite |
| Service Account Credentials | Secret | Critical | KMS (automatic) | N/A |

### Data Protection Measures

#### 1. Encryption

**At Rest**:
- Cloud Storage: AES-256 (Google-managed keys)
- BigQuery: AES-256 (Google-managed keys)
- Artifact Registry: AES-256 (Google-managed keys)

**In Transit**:
- TLS 1.2+ for all connections
- HTTPS for external API calls
- Encrypted internal GCP networking

#### 2. Access Controls

```hcl
# Uniform bucket-level access (no ACLs)
resource "google_storage_bucket" "data" {
  uniform_bucket_level_access = true
}
```

#### 3. Data Lifecycle

```hcl
lifecycle_rule {
  condition {
    age = 30  # Delete after 30 days
  }
  action {
    type = "Delete"
  }
}
```

#### 4. BigQuery Security

**Table Partitioning** (Query Cost Optimization):
```hcl
time_partitioning {
  type  = "DAY"
  field = "ingestion_date"
}
```

**Dataset Access Control**:
- Only `ingest-runner` service account has `dataEditor` role
- Human users should have `roles/bigquery.dataViewer` for read-only access

#### 5. Data Backup & Recovery

**Current State**:
- BigQuery: Automatic 7-day time travel
- Cloud Storage: 30-day retention before deletion

**Recommendations**:
- Enable BigQuery dataset snapshots for long-term retention
- Configure GCS versioning for critical data
- Implement cross-region replication for disaster recovery

---

## Container Security

### Current Dockerfile Analysis

```dockerfile
FROM python:3.11-slim                    # ✅ Minimal base image
ENV PYTHONDONTWRITEBYTECODE=1           # ✅ No .pyc files
    PYTHONUNBUFFERED=1                  # ✅ Real-time logging
    PORT=8080                           # ✅ Non-privileged port

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt  # ✅ No cache
COPY main.py .

CMD ["gunicorn", "-w", "1", "--threads", "2", ...]  # ✅ Production server
```

### Security Enhancements

#### 1. Non-Root User

**Add to Dockerfile**:

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

# Install dependencies as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Copy application files
COPY --chown=appuser:appuser main.py .

# Switch to non-root user
USER appuser

CMD ["gunicorn", "-w", "1", "--threads", "2", "--timeout", "120", "-k", "gthread", "-b", "0.0.0.0:8080", "main:app"]
```

#### 2. Multi-Stage Build (Future Enhancement)

```dockerfile
# Build stage
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY main.py .
ENV PATH=/root/.local/bin:$PATH
USER 1000
CMD ["gunicorn", "..."]
```

#### 3. Image Scanning

Add to CI/CD:

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.image.outputs.image_ref }}
    format: 'table'
    exit-code: '1'  # Fail on HIGH/CRITICAL vulnerabilities
    severity: 'CRITICAL,HIGH'
```

#### 4. Distroless Images (Advanced)

Consider Google's distroless base images:

```dockerfile
FROM gcr.io/distroless/python3-debian11
```

---

## Secrets Management

### Current Approach

**Environment Variables**: Secrets passed as Cloud Run environment variables

```hcl
env {
  name  = "BUCKET"
  value = var.bucket_name
}
```

### Best Practices

1. **No Secrets in Code**: ✅ Implemented
2. **No Secrets in Logs**: ✅ Verified
3. **No Secrets in Container Images**: ✅ Verified
4. **Environment Variables**: ✅ Used for non-sensitive config

### Enhanced Secrets Management (Recommended)

For sensitive data, use **Secret Manager**:

```hcl
resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-key"
  replication {
    auto {}
  }
}

# Mount secret in Cloud Run
resource "google_cloud_run_v2_service" "ingest" {
  template {
    volumes {
      name = "secrets"
      secret {
        secret       = google_secret_manager_secret.api_key.secret_id
        default_mode = 0444
        items {
          path    = "api_key"
          version = "latest"
        }
      }
    }
    containers {
      volume_mounts {
        name       = "secrets"
        mount_path = "/secrets"
      }
    }
  }
}
```

**Access in Python**:

```python
with open('/secrets/api_key', 'r') as f:
    API_KEY = f.read().strip()
```

### Secrets Rotation

**Current State**: No secrets requiring rotation (public data source)

**For Future Secrets**:
- Implement automatic rotation every 90 days
- Use Secret Manager versioning
- Update Cloud Run service to use latest version

---

## Compliance & Auditing

### Audit Logging

**Enabled by Default**:
- Admin Activity Logs: All administrative actions logged
- Data Access Logs: Can be enabled for sensitive data
- System Event Logs: GCP system events

**View Audit Logs**:

```bash
# Cloud Run audit logs
gcloud logging read "protoPayload.serviceName=run.googleapis.com" \
  --limit=50 \
  --format=json

# IAM changes
gcloud logging read "protoPayload.methodName:SetIamPolicy" \
  --limit=50

# BigQuery data access (if enabled)
gcloud logging read "protoPayload.serviceName=bigquery.googleapis.com" \
  --limit=50
```

### Compliance Frameworks

This architecture can support:

- **SOC 2 Type II**: Audit logs, access controls, encryption
- **ISO 27001**: Security controls documentation
- **GDPR**: Data lifecycle, encryption, access controls (if handling EU data)
- **HIPAA**: Additional controls needed for PHI

### Audit Checklist

#### Monthly Audits

- [ ] Review IAM policy changes
- [ ] Check for new service accounts
- [ ] Verify no service account keys exported
- [ ] Review Cloud Run access logs
- [ ] Check BigQuery data access patterns
- [ ] Verify lifecycle policies functioning

#### Quarterly Audits

- [ ] Full IAM permissions review
- [ ] Dependency vulnerability scan
- [ ] Container image security scan
- [ ] Cost anomaly detection
- [ ] Disaster recovery test
- [ ] Incident response drill

#### Annual Audits

- [ ] Complete security architecture review
- [ ] Compliance assessment
- [ ] Third-party security audit
- [ ] Penetration testing
- [ ] Business continuity planning

---

## Vulnerability Management

### Dependency Scanning

**Python Dependencies**:

```bash
# Install safety
pip install safety

# Scan for known vulnerabilities
safety check -r requirements.txt --json
```

**Automate in CI/CD**:

```yaml
- name: Security scan dependencies
  run: |
    pip install safety
    safety check -r app/requirements.txt --exit-code 1
```

### Container Image Scanning

**Trivy** (recommended):

```bash
# Scan local image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image us-central1-docker.pkg.dev/PROJECT/app-images/ingest:latest

# Scan for HIGH and CRITICAL only
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL \
  us-central1-docker.pkg.dev/PROJECT/app-images/ingest:latest
```

### Terraform Security Scanning

**tfsec**:

```bash
# Install tfsec
brew install tfsec  # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Scan Terraform code
cd infra
tfsec .
```

**Checkov**:

```bash
pip install checkov
checkov -d infra/
```

### Vulnerability Response SLA

| Severity | Response Time | Remediation Time |
|----------|--------------|------------------|
| Critical | 24 hours | 48 hours |
| High | 7 days | 30 days |
| Medium | 30 days | 90 days |
| Low | 90 days | Next release |

---

## Incident Response

### Incident Response Plan

#### 1. Detection

**Monitoring Sources**:
- Cloud Logging alerts
- Error Reporting dashboards
- Cost anomaly alerts
- Security Command Center findings

#### 2. Classification

**Severity Levels**:

- **P0 (Critical)**: Data breach, service compromise, credential theft
- **P1 (High)**: Service outage, failed security control, vulnerability exploitation attempt
- **P2 (Medium)**: Suspicious activity, policy violation, degraded performance
- **P3 (Low)**: Minor security finding, best practice deviation

#### 3. Response Procedures

**P0 - Critical Incident**:

1. **Immediate Actions** (< 15 minutes):
   - Disable compromised service accounts
   - Block malicious IPs at Cloud Armor (if applicable)
   - Isolate affected resources

```bash
# Disable service account
gcloud iam service-accounts disable ingest-runner@PROJECT.iam.gserviceaccount.com

# Pause Cloud Scheduler
gcloud scheduler jobs pause daily-ingest --location=us-central1

# Delete Cloud Run service (if compromised)
gcloud run services delete ingest --region=us-central1
```

2. **Investigation** (< 1 hour):
   - Review audit logs for unauthorized access
   - Check Data Access logs for data exfiltration
   - Analyze Cloud Run logs for malicious activity

3. **Containment** (< 4 hours):
   - Rotate all credentials
   - Deploy clean infrastructure from IaC
   - Enable VPC Service Controls

4. **Recovery** (< 24 hours):
   - Redeploy infrastructure with hardened security
   - Restore data from backups if needed
   - Verify integrity of all resources

5. **Post-Incident** (< 7 days):
   - Root cause analysis
   - Update security controls
   - Document lessons learned
   - Notify stakeholders

**P1 - High Severity**:
- Response within 1 hour
- Investigation within 4 hours
- Remediation within 24 hours

**P2/P3 - Medium/Low Severity**:
- Response within 24 hours
- Plan remediation within 1 week

#### 4. Communication Plan

**Internal**:
- Incident commander notified immediately
- Engineering team notified within 15 minutes
- Management notified within 1 hour (P0/P1)

**External**:
- No external communication required (public data only)
- For future sensitive data: Comply with breach notification laws

### Emergency Contacts

```
Security Lead: security@yourcompany.com
Incident Commander: oncall@yourcompany.com
GCP Support: https://cloud.google.com/support
GitHub Security: https://github.com/security/advisories
```

### Incident Response Runbooks

#### Compromised Service Account

```bash
# 1. Disable service account
gcloud iam service-accounts disable SA_EMAIL

# 2. Review activity
gcloud logging read "protoPayload.authenticationInfo.principalEmail=SA_EMAIL" \
  --limit=100

# 3. Remove all IAM bindings
gcloud projects remove-iam-policy-binding PROJECT \
  --member=serviceAccount:SA_EMAIL \
  --role=ROLE

# 4. Delete and recreate
gcloud iam service-accounts delete SA_EMAIL
terraform apply  # Recreates service account
```

#### Suspicious Cloud Run Activity

```bash
# 1. Pause scheduler
gcloud scheduler jobs pause daily-ingest --location=us-central1

# 2. Review logs
gcloud logging read "resource.type=cloud_run_revision" --limit=200

# 3. Check for unauthorized requests
gcloud logging read "resource.type=cloud_run_revision AND httpRequest.status >= 400"

# 4. Update to internal ingress only
# Update Terraform: ingress = "INGRESS_TRAFFIC_INTERNAL"
terraform apply

# 5. Resume when confirmed safe
gcloud scheduler jobs resume daily-ingest --location=us-central1
```

---

## Security Checklist

### Pre-Deployment Checklist

- [ ] All Terraform code scanned with tfsec/checkov
- [ ] Container image scanned for vulnerabilities
- [ ] Python dependencies checked with safety
- [ ] No secrets in code or environment variables
- [ ] IAM roles follow least-privilege principle
- [ ] Service accounts have no exported keys
- [ ] Cloud Run ingress set appropriately
- [ ] Lifecycle policies configured
- [ ] Audit logging enabled
- [ ] Resource limits configured

### Post-Deployment Checklist

- [ ] Verify service accounts created correctly
- [ ] Test Cloud Run authentication
- [ ] Verify data flows to BigQuery
- [ ] Check Cloud Logging for errors
- [ ] Test Cloud Scheduler trigger
- [ ] Verify GCS lifecycle working
- [ ] Review initial audit logs
- [ ] Document all resources created
- [ ] Set up monitoring alerts
- [ ] Test incident response procedures

### Monthly Security Tasks

- [ ] Review audit logs for anomalies
- [ ] Check for new IAM policy changes
- [ ] Scan container images for vulnerabilities
- [ ] Update dependencies if needed
- [ ] Review cost reports for anomalies
- [ ] Verify backups functioning
- [ ] Test service account permissions
- [ ] Review Cloud Logging retention

### Quarterly Security Tasks

- [ ] Full IAM permissions audit
- [ ] Container security scan
- [ ] Dependency vulnerability assessment
- [ ] Disaster recovery test
- [ ] Security documentation update
- [ ] Compliance checklist review
- [ ] Incident response drill
- [ ] Third-party library updates

---

## Reporting Security Issues

### Responsible Disclosure

If you discover a security vulnerability in this project:

**DO**:
- ✅ Report via private channel (email)
- ✅ Provide detailed reproduction steps
- ✅ Allow reasonable time for fix (90 days)
- ✅ Verify fix before public disclosure

**DON'T**:
- ❌ Open public GitHub issues for vulnerabilities
- ❌ Exploit vulnerability for malicious purposes
- ❌ Disclose publicly before fix is available
- ❌ Demand compensation for disclosure


### Vulnerability Disclosure Process

1. **Report Received**: Security team acknowledges receipt
2. **Validation**: Team reproduces and validates vulnerability
3. **Assessment**: Severity rating assigned (CVSS score)
4. **Fix Development**: Patch developed and tested
5. **Fix Deployment**: Patch deployed to production
6. **Public Disclosure**: Coordinated disclosure after 90 days or fix deployment
7. **Credit**: Reporter credited in security advisory (if desired)

---

## Additional Resources

### Security Tools

- **Terraform Security**: [tfsec](https://github.com/aquasecurity/tfsec), [checkov](https://www.checkov.io/)
- **Container Scanning**: [Trivy](https://github.com/aquasecurity/trivy), [Grype](https://github.com/anchore/grype)
- **Dependency Scanning**: [Safety](https://pyup.io/safety/), [pip-audit](https://github.com/pypa/pip-audit)
- **SAST**: [Bandit](https://github.com/PyCQA/bandit), [Semgrep](https://semgrep.dev/)
- **Secrets Detection**: [gitleaks](https://github.com/gitleaks/gitleaks), [TruffleHog](https://github.com/trufflesecurity/truffleHog)

### GCP Security Best Practices

- [Google Cloud Security Best Practices](https://cloud.google.com/security/best-practices)
- [Cloud Run Security](https://cloud.google.com/run/docs/securing/securing)
- [IAM Best Practices](https://cloud.google.com/iam/docs/best-practices)
- [BigQuery Security](https://cloud.google.com/bigquery/docs/best-practices-security)
- [GCS Security](https://cloud.google.com/storage/docs/best-practices)

### Compliance Resources

- [SOC 2 Compliance on GCP](https://cloud.google.com/security/compliance/soc-2)
- [GDPR Compliance](https://cloud.google.com/privacy/gdpr)
- [HIPAA Compliance](https://cloud.google.com/security/compliance/hipaa)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-10 | Initial security policy |

---
