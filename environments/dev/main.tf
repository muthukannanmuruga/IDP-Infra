provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "IDP-Infra"
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
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

module "github_oidc" {
  source = "../../modules/github-oidc"

  ecr_repository_arn = module.demo_service_ecr.repository_arn
  github_org         = "muthukannanmuruga"
  github_repository  = "demo-service"
  github_branch      = "main"

  tags = {
    Environment = "dev"
    Project     = "IDP-Infra"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.5.5"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  depends_on = [kubernetes_namespace.argocd]
}