locals {
  common_tags = {
    Compliance  = "PCI-DSS-v4.0_SOX-ITGC_GLBA"
    Environment = var.environment
    ManagedBy   = "Terraform-Golden-Path"
  }
}

resource "aws_kms_key" "pci_cmk" {
  description             = "PCI-DSS v4.0 Req 3/4 CMK with annual rotation"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "S3Use"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.bucket_prefix}-${var.environment}-audit-logs-${var.aws_account_id}"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.pci_cmk.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket" "cde_vault" {
  bucket              = "${var.bucket_prefix}-${var.environment}-cde-vault-${var.aws_account_id}"
  force_destroy       = false
  object_lock_enabled = true
  tags                = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "cde_vault" {
  bucket                  = aws_s3_bucket.cde_vault.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.cde_vault]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.pci_cmk.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "cde_vault" {
  bucket        = aws_s3_bucket.cde_vault.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cde-access-logs/"
}

resource "aws_s3_bucket_policy" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.cde_vault.arn, "${aws_s3_bucket.cde_vault.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "ForbidManualStateMutation"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:PutObjectRetention"]
        Resource  = [aws_s3_bucket.cde_vault.arn, "${aws_s3_bucket.cde_vault.arn}/*"]
        Condition = { StringNotLike = { "aws:PrincipalArn" = "arn:aws:iam::${var.aws_account_id}:role/*terraform*" } }
      }
    ]
  })
}
