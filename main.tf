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
      { Sid = "RootAdmin", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }, Action = "kms:*", Resource = "*" },
      { Sid = "S3Use", Effect = "Allow", Principal = { Service = "s3.amazonaws.com" }, Action = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = "*" }
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

