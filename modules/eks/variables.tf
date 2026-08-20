variable "name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane and managed node group."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster and security groups are created."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS control plane and managed node group."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnet IDs must be provided."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 3
}

variable "node_group_name" {
  description = "Optional managed node group name."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to EKS resources."
  type        = map(string)
  default     = {}
}