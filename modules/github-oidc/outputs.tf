output "provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github.arn
}

output "role_arn" {
  description = "ARN of the GitHub Actions ECR role."
  value       = aws_iam_role.github_actions_ecr.arn
}