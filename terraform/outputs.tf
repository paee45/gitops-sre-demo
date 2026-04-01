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
  description = "ARN of the GitHub Actions IAM role — set this as the AWS_ROLE_ARN repo secret"
  value       = aws_iam_role.github_actions.arn
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh admin@${aws_instance.k3s.public_ip}"
}

output "ami_id" {
  description = "Debian 12 AMI used for the instance"
  value       = data.aws_ami.debian_12.id
}
