variable "aws_region" {
  description = "AWS region for the development environment."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones used by the VPC."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cluster_name" {
  description = "EKS cluster name used for subnet tags."
  type        = string
  default     = "idp-dev-eks"
}

variable "node_instance_types" {
  description = "EC2 instance types for the development EKS node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of development EKS nodes."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of development EKS nodes."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of development EKS nodes."
  type        = number
  default     = 5
}