variable "illumio_cloudsecure_client_id" {
  type        = string
  description = "The OAuth 2 client identifier used to authenticate against the CloudSecure Config API."
}

variable "illumio_cloudsecure_client_secret" {
  type        = string
  sensitive   = true
  description = "The OAuth 2 client secret used to authenticate against the CloudSecure Config API."
}

variable "azure_subscription_id" {
  type        = string
  description = "The Azure Subscription ID."
  validation {
    condition     = length(var.azure_subscription_id) > 0
    error_message = "The azure_subscription_id value must not be empty."
  }
}

variable "azure_client_id" {
  type        = string
  description = "The Azure Client ID."
  validation {
    condition     = length(var.azure_client_id) > 0
    error_message = "The azure_client_id value must not be empty."
  }
}

variable "azure_client_secret" {
  type        = string
  sensitive   = true
  description = "The Azure Client Secret."
  validation {
    condition     = length(var.azure_client_secret) > 0
    error_message = "The azure_client_secret value must not be empty."
  }
}

variable "azure_tenant_id" {
  type        = string
  description = "The Azure Tenant ID."
  validation {
    condition     = length(var.azure_tenant_id) > 0
    error_message = "The azure_tenant_id value must not be empty."
  }
}
# variable "aws_account_id" {
#   type        = string
#   sensitive   = true
#   description = "AWS acount id."
# }

# variable "role_arn" {
#   type        = string
#   sensitive   = true
#   description = "The AWS role arn for onboarding aws."
# }

# variable "role_external_id" {
#   type        = string
#   sensitive   = true
#   description = "The AWS role id for onboarding aws."
# }

# variable "storage_bucket_arn" {
#   type        = string
#   sensitive   = true
#   description = "The S3 bucket ARN for flow logs."
  
# }