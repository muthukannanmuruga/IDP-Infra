variable "oidc_url" {
  description = "GitHub Actions OIDC issuer URL."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "audience" {
  description = "Audience accepted by the GitHub Actions OIDC provider."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_org_id" {
  description = "Numeric GitHub organization ID included in the Actions OIDC subject."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the role."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the role."
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository that GitHub Actions may push to."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to the OIDC provider."
  type        = map(string)
  default     = {}
}