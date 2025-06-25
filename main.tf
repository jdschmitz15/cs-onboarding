
module "aws_account_dev" {
  source  = "illumio/cloudsecure/illumio//modules/aws_account"
  version = "1.5.1"
  name    = "Test Account"
  tags    = {
    Name  = "CloudSecure Account Policy"
    Owner = "Engineering"
  }
}

module "azure_subscription_dev" {
  source                 = "illumio/cloudsecure/illumio//modules/azure_subscription"
  version                = "1.5.1"
  name                   = "Test Azure Subscription"
  mode                   = "ReadWrite"
#   secret_expiration_days = 365
#   subscription_id        = var.azure_subscription_id # Azure Subscription ID
#   tenant_id              = var.azure_tenant_id # Azure Tenant ID

  tags = [
    "Environment=Dev",
    "Owner=John Doe"
  ]
}