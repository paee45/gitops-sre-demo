variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium (4 GB) is default. Upgrade to t3.large if OOM."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Leave empty to skip key attachment."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance. Restrict to your IP."
  type        = string
  default     = "0.0.0.0/0" # Restrict in production: e.g. 1.2.3.4/32
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repo (e.g. my-org)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name without org prefix (e.g. gitops-sre-demo)"
  type        = string
}

variable "tf_state_bucket" {
  description = "Name of the pre-existing S3 bucket used for Terraform state"
  type        = string
}

variable "tf_state_dynamodb_table" {
  description = "Name of the pre-existing DynamoDB table used for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}

variable "project_name" {
  description = "Short name used as a prefix for all AWS resources"
  type        = string
  default     = "gitops-sre-demo"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB (gp3)"
  type        = number
  default     = 30
}
