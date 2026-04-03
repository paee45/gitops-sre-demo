variable "aws_account_id" {
  description = "Your personal AWS account ID. Set this to prevent accidental deploys to the wrong account. Leave empty to skip check."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region to create the backend resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging"
  type        = string
  default     = "gitops-sre-demo"
}

variable "tf_state_bucket" {
  description = "Globally unique S3 bucket name for Terraform state. Must not already exist."
  type        = string
}

variable "tf_state_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}
