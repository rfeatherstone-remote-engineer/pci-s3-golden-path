
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "pci-audit-log-retention"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    transition { days = 90
      storage_class = "GLACIER" }
    expiration { days = var.retention_days }
  }
}

resource "aws_s3_bucket" "cde_vault" {
  bucket              = "${var.bucket_prefix}-${var.environment}-${var.aws_account_id}"
  object_lock_enabled = true
  force_destroy       = false
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
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "cde_vault" {
  bucket     = aws_s3_bucket.cde_vault.id
  depends_on = [aws_s3_bucket_versioning.cde_vault]
  rule {
    default_retention { mode = "COMPLIANCE"
      days = var.retention_days }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  rule {
    apply_server_side_encryption_by_default { kms_master_key_id = aws_kms_key.pci_cmk.arn
      sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cde_vault" {
  bucket = aws_s3_bucket.cde_vault.id
  rule {
    id     = "pci-sox-7yr-tiering"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    transition { days = 90
      storage_class = "STANDARD_IA" }
    transition { days = 365
      storage_class = "GLACIER" }
  }
}

resource "aws_s3_bucket_logging" "cde_vault" {
  bucket        = aws_s3_bucket.cde_vault.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
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
        Sid       = "DenyNonKMSUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cde_vault.arn}/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      }
    ]
  })
}
