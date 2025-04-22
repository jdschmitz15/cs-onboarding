resource "illumio-cloudsecure_aws_account" "aws_onboarded" {
  account_id       = var.aws_account_id
  name             = "HOL Onboarded AWS Account"
  role_arn         = var.role_arn
  role_external_id = var.role_external_id

  # Optional attributes
  mode            = "ReadWrite"
  #organization_id = "o-3eehyj6qk0"
}

resource "illumio-cloudsecure_aws_flow_logs_s3_bucket" "flow_log_bucket" {
  account_id    = var.aws_account_id
  s3_bucket_arn = var.storage_bucket_arn
}