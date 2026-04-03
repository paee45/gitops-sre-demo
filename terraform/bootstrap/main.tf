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

  # Object Lock must be enabled at bucket creation time — cannot be added later.
  # GOVERNANCE mode: prevents deletion without s3:BypassGovernanceRetention permission.
  # Protects state files from accidental `terraform destroy` of the bucket itself.
  object_lock_enabled = true

  # Prevent accidental deletion of the bucket while state files exist
  lifecycle {
    prevent_destroy = true
  }
}

# Default retention: GOVERNANCE mode, 30 days.
# This means every object version is protected for 30 days after upload.
# Terraform state objects are re-uploaded on every apply — the 30-day window
# gives you a safe recovery window if state is accidentally overwritten.
resource "aws_s3_bucket_object_lock_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
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
# Bootstrap IAM policy — attach this to the human/role that runs bootstrap.
# Replace AdministratorAccess with this policy: it is the MINIMUM needed to
# run `terraform apply` in this bootstrap directory.
# After bootstrap completes, all further writes go through GitHub Actions OIDC.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bootstrap_user" {
  # Must be able to verify which account is active
  statement {
    sid    = "STS"
    effect = "Allow"
    actions = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # Create/manage the S3 state bucket and its settings
  statement {
    sid    = "S3StateBucket"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:PutBucketObjectLockConfiguration",  # required to set Object Lock rules
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:BypassGovernanceRetention",          # required to delete GOVERNANCE-locked objects (cleanup)
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*",
    ]
  }

  # Create/manage the DynamoDB lock table
  statement {
    sid    = "DynamoDBLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource",
      "dynamodb:UpdateTable",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.tf_state_dynamodb_table}",
    ]
  }
}

resource "aws_iam_policy" "bootstrap_user" {
  name        = "${var.project_name}-bootstrap-user-policy"
  description = "Minimum permissions to run terraform/bootstrap — replaces AdministratorAccess"
  policy      = data.aws_iam_policy_document.bootstrap_user.json

  tags = {
    Name = "${var.project_name}-bootstrap-user-policy"
  }
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
