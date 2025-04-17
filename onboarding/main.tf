resource "illumio-cloudsecure_aws_account" "aws_onboarded" {
  account_id       = var.aws_account_id
  name             = "HOL Onboarded AWS Account"
  role_arn         = var.role_arn
  role_external_id = var.role_id

  # Optional attributes
  mode            = "ReadWrite"
  #organization_id = "o-3eehyj6qk0"
}