provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

module "pci_cde_vault" {
  source         = "../../"
  aws_account_id = "123456789012"
  environment    = "cde"
  bucket_prefix  = "pci-cde-vault"
  retention_days = 2555
}
