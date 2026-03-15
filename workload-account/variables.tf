variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}


variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}


variable "security_account_id" {
  description = "AWS Account ID of the Security account that is trusted to assume roles here"
  type        = string
  # You will set this in terraform.tfvars or via -var flag
}
