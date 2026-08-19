terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  cloud {
    organization = "MK_Internal_Developer_Platform"

    workspaces {
      name = "IDP-Infra"
    }
  }
}
