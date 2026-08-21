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

variable "tags" {
  description = "Additional tags applied to the OIDC provider."
  type        = map(string)
  default     = {}
}