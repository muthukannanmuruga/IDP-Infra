output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA data for the EKS cluster API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_security_group_id" {
  description = "Security group ID assigned to the EKS control plane."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID assigned to EKS managed nodes."
  value       = aws_security_group.nodes.id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider used by cluster service accounts."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL used by cluster service accounts."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "Name of the EKS managed node group."
  value       = aws_eks_node_group.this.node_group_name
}