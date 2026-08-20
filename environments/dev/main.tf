provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "IDP-Infra"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = "idp-dev-vpc"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = var.availability_zones
  cluster_name       = var.cluster_name

  tags = {
    Environment = "dev"
    Project     = "IDP-Infra"
  }
}

module "eks" {
  source = "../../modules/eks"

  name                = var.cluster_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  vpc_id              = module.vpc.vpc_id
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size

  tags = {
    Environment = "dev"
    Project     = "IDP-Infra"
  }
}

module "demo_service_ecr" {
  source = "../../modules/ecr"

  repository_name = "demo-service"

  tags = {
    Environment = "dev"
    Project     = "IDP-Infra"
    Service     = "demo-service"
  }
}