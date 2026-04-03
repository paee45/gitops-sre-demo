output "aws_account_id" {
  description = "AWS account ID where backend resources were created — use this in terraform/terraform.tfvars as aws_account_id"
  value       = data.aws_caller_identity.current.account_id
}

output "bootstrap_policy_arn" {
  description = "ARN of the scoped bootstrap IAM policy — attach this to your bootstrap user INSTEAD of AdministratorAccess"
  value       = aws_iam_policy.bootstrap_user.arn
}

output "tf_state_bucket" {
  description = "S3 bucket name — copy into terraform/terraform.tfvars as tf_state_bucket"
  value       = aws_s3_bucket.tf_state.bucket
}

output "tf_state_dynamodb_table" {
  description = "DynamoDB table name — copy into terraform/terraform.tfvars as tf_state_dynamodb_table"
  value       = aws_dynamodb_table.tf_locks.name
}

output "backend_config" {
  description = "Snippet to use when running terraform init for the main config"
  value       = <<-EOT
    terraform init \
      -backend-config="bucket=${aws_s3_bucket.tf_state.bucket}" \
      -backend-config="key=gitops-sre-demo/terraform.tfstate" \
      -backend-config="region=${var.aws_region}" \
      -backend-config="dynamodb_table=${aws_dynamodb_table.tf_locks.name}"
  EOT
}

  description = "S3 bucket name — copy into terraform/terraform.tfvars as tf_state_bucket"
  value       = aws_s3_bucket.tf_state.bucket
}

output "tf_state_dynamodb_table" {
  description = "DynamoDB table name — copy into terraform/terraform.tfvars as tf_state_dynamodb_table"
  value       = aws_dynamodb_table.tf_locks.name
}

output "backend_config" {
  description = "Snippet to use when running terraform init for the main config"
  value       = <<-EOT
    terraform init \
      -backend-config="bucket=${aws_s3_bucket.tf_state.bucket}" \
      -backend-config="key=gitops-sre-demo/terraform.tfstate" \
      -backend-config="region=${var.aws_region}" \
      -backend-config="dynamodb_table=${aws_dynamodb_table.tf_locks.name}"
  EOT
}
