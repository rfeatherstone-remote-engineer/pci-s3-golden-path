# PCI-DSS v4.0 / SEC 17a-4(f) Compliant S3 Storage Module ("Golden Path")

[![PCI-DSS S3 Golden Path CI](https://github.com/rfeatherstone-remote-engineer/pci-s3-golden-path/actions/workflows/ci.yml/badge.svg)](https://github.com/rfeatherstone-remote-engineer/pci-s3-golden-path/actions/workflows/ci.yml)

**Self-Service Infrastructure Guardrail:** Production-hardened Terraform module providing compliant-by-default AWS S3 object storage for Cardholder Data Environments (CDE) and regulated financial records.

## Enforced Technical Safeguards

1. **Cryptographic Isolation (PCI-DSS v4.0 Req 3.5 / GLBA):** Dedicated Customer-Managed KMS Key (CMK) with automatic annual rotation and S3 Bucket Keys enabled (`aws:kms`).
2. **Immutable WORM Storage (SEC 17a-4(f) / FINRA 4511 / PCI Req 10.5.1):** Versioning + S3 Object Lock enforced in `COMPLIANCE` mode for a minimum of `2,555` days (7 years).
3. **Zero Public Exposure (PCI-DSS Req 1.3):** Strict 100% Public Access Block across both the CDE Vault and centralized audit log bucket.
4. **Tamper-Evident Audit Logging (SOX 404 / PCI Req 10.2):** Dedicated server access logging bucket with independent KMS encryption and public access blocks.
5. **Transport & Anti-ClickOps Guardrails:** Bucket policy explicitly denies non-TLS (`aws:SecureTransport = false`) requests and blocks manual state mutation (`ForbidManualStateMutation`) outside Terraform CI/CD roles.

## Compliance Control Matrix

| Control Domain | Regulatory Citation | Enforced Terraform Guardrail |
| :--- | :--- | :--- |
| **Encryption at Rest** | PCI-DSS v4.0 Req 3.5 / GLBA | CMK KMS (`enable_key_rotation = true`) + S3 Bucket Keys |
| **WORM Immutability** | SEC Rule 17a-4(f) / FINRA 4511 | S3 Object Lock (`COMPLIANCE` mode, `>= 2,555` days) |
| **Network & Access** | PCI-DSS v4.0 Req 1.3 / 4.2 | 100% Public Access Block + `DenyInsecureTransport` (TLS-only) |
| **Change Integrity** | SOX Section 404 (ITGC) | `ForbidManualStateMutation` bucket policy + offline CI gates |
| **Audit Trail** | PCI-DSS v4.0 Req 10.2 | Dedicated KMS-encrypted server access logging bucket |

## Architecture Overview

```text
+-----------------------------------------------------------------------+
|  Authorized CI/CD Terraform Role (Anti-ClickOps Enforced)             |
+-----------------------------------+-----------------------------------+
                                    | TLS 1.2+ Only (DenyInsecureTransport)
                                    v
+-----------------------------------------------------------------------+
|  Primary CDE Vault (aws_s3_bucket.cde_vault)                          |
|  * CMK KMS Encryption + Annual Rotation + Bucket Key                  |
|  * S3 Object Lock (COMPLIANCE Mode, >= 2,555 Days / 7 Years)          |
|  * 100% Public Access Block + Versioning Enabled                      |
+-----------------------------------+-----------------------------------+
                                    | Server Access Logs
                                    v
+-----------------------------------------------------------------------+
|  Centralized Audit Log Bucket (aws_s3_bucket.access_logs)             |
|  * Independent CMK Encryption + Versioning + 100% Public Access Block |
+-----------------------------------------------------------------------+
```

## Automated CI Compliance Gate (100% Offline)

Every commit and pull request runs a zero-credential Policy-as-Code pipeline (`ci.yml`):
- **Formatting & Syntax:** `terraform fmt -check -recursive` and `terraform validate`
- **Offline Execution Plan:** `terraform plan` using mocked provider flags and validated `aws_account_id = "123456789012"`
- **Static Security & Policy Scanning:** `trivy` and `checkov` compliance verification

## Quick Start (Offline Plan)

```bash
cd examples/basic
terraform init -backend=false
terraform plan
```
