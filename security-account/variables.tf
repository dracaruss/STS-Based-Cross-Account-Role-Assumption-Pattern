variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "workload_account_id" {
  description = "AWS Account ID of the Workload account where roles are defined"
  type        = string
  # You will set this in terraform.tfvars or via -var flag
}
