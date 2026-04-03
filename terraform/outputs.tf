output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "Public IP of the K3s node"
  value       = aws_instance.k3s.public_ip
}

output "public_dns" {
  description = "Public DNS of the K3s node"
  value       = aws_instance.k3s.public_dns
}

output "grafana_url" {
  description = "Grafana UI URL (NodePort)"
  value       = "http://${aws_instance.k3s.public_ip}:3000"
}

output "argocd_url" {
  description = "ArgoCD UI URL (NodePort)"
  value       = "http://${aws_instance.k3s.public_ip}:32080"
}

output "iam_role_arn" {
  description = "ARN of the GitHub Actions APPLY IAM role — set as secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "iam_plan_role_arn" {
  description = "ARN of the GitHub Actions PLAN IAM role — set as secret AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.github_plan.arn
}

output "aws_account_id" {
  description = "AWS account ID where resources were deployed — set as secret AWS_ACCOUNT_ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ssh_key_secret_arn" {
  description = "Secrets Manager ARN of the EC2 SSH private key"
  value       = aws_secretsmanager_secret.ssh_key.arn
}

output "ssh_command" {
  description = "One-liner: retrieve key from Secrets Manager then SSH into the instance"
  value       = <<-EOT
    aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.ssh_key.arn} \
      --query SecretString --output text > /tmp/${var.project_name}.pem && \
    chmod 600 /tmp/${var.project_name}.pem && \
    ssh -i /tmp/${var.project_name}.pem admin@${aws_instance.k3s.public_ip}
  EOT
}

output "ami_id" {
  description = "Debian 12 AMI used for the instance"
  value       = data.aws_ami.debian_12.id
}
