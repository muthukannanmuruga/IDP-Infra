output "provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : (var.oidc_provider_arn != null ? var.oidc_provider_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.oidc_url, "https://", "")}")
}

output "role_arn" {
  description = "ARN of the GitHub Actions ECR role."
  value       = aws_iam_role.github_actions_ecr.arn
}