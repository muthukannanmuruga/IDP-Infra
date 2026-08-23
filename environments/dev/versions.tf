terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }

  cloud {
    organization = "MK_Internal_Developer_Platform"
    #dummy-comment
    workspaces {
      name = "IDP-Infra"
    }
  }
}
