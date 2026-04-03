# Bootstrap — run ONCE with local state to create the Terraform remote backend.
# After this apply, the main terraform/ config can use the S3 backend.
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#   # Copy the outputs into terraform/terraform.tfvars (tf_state_bucket, tf_state_dynamodb_table)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Intentionally local state — this config bootstraps the remote backend itself.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "terraform-state-backend"
    }
  }
}

# ---------------------------------------------------------------------------
# Account guard — fail immediately if the wrong AWS account is active
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  account_ok = var.aws_account_id == "" || data.aws_caller_identity.current.account_id == var.aws_account_id
}

resource "null_resource" "account_guard" {
  # Terraform will error here before creating anything if the account is wrong.
  count = local.account_ok ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "\n"
      echo "  ERROR: Wrong AWS account!"
      echo "  Expected : ${var.aws_account_id}"
      echo "  Active   : ${data.aws_caller_identity.current.account_id}"
      echo "  Run: aws configure --profile personal   (then re-export AWS_PROFILE=personal)"
      echo "\n"
      exit 1
    EOT
  }
}

# ---------------------------------------------------------------------------
# S3 — Terraform state bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  bucket = var.tf_state_bucket

  # Prevent accidental deletion of the bucket while state files exist
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB — Terraform state lock table
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "tf_locks" {
  name         = var.tf_state_dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-tf-locks"
  }
}
