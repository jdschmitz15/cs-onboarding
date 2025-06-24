variable "illumio_cloudsecure_client_id" {
  type        = string
  description = "The OAuth 2 client identifier used to authenticate against the CloudSecure Config API."
}

variable "illumio_cloudsecure_client_secret" {
  type        = string
  sensitive   = true
  description = "The OAuth 2 client secret used to authenticate against the CloudSecure Config API."
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