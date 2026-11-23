output "cde_vault_bucket_id" { value = aws_s3_bucket.cde_vault.id }
output "cde_vault_bucket_arn" { value = aws_s3_bucket.cde_vault.arn }
output "access_logs_bucket_id" { value = aws_s3_bucket.access_logs.id }
output "kms_key_arn" { value = aws_kms_key.pci_cmk.arn }
