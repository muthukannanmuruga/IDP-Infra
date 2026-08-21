data "tls_certificate" "github" {
  url = var.oidc_url
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = var.oidc_url
  client_id_list  = [var.audience]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name      = "github-actions"
    ManagedBy = "Terraform"
  })
}