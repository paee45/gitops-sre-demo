# terraform/bootstrap/terraform.tfvars
# S3 bucket names are globally unique — prefix with your GitHub username to avoid conflicts.
aws_region              = "us-east-1"
project_name            = "gitops-sre-demo"
tf_state_bucket         = "paee45-gitops-sre-tf-state"
tf_state_dynamodb_table = "terraform-state-lock"
