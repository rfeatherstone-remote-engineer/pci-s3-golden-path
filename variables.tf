variable "aws_account_id" {
  type        = string
  description = "12-digit AWS account ID for offline policy rendering."
  default     = "123456789012"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit numeric string."
  }
}

variable "environment" {
  type        = string
  default     = "cde"
}

variable "bucket_prefix" {
  type        = string
  default     = "pci-cde-vault"
}

variable "retention_days" {
  type        = number
  default     = 2555
  validation {
    condition     = var.retention_days >= 2555
    error_message = "Requires at least 2555 days (7 years)."
  }
}
