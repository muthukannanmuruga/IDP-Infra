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

data "aws_iam_policy_document" "cluster_autoscaler_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role.json
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name   = "${var.cluster_name}-cluster-autoscaler"
  role   = aws_iam_role.cluster_autoscaler.id
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
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

locals {
  service_files = fileset(path.module, "services/*.yaml")
  services = {
    for file_name in local.service_files :
    yamldecode(file("${path.module}/${file_name}")).name => yamldecode(file("${path.module}/${file_name}"))
  }
}

moved {
  from = module.demo_service_ecr
  to   = module.service_ecr["demo-service"]
}

moved {
  from = module.github_oidc["demo-service"].aws_iam_openid_connect_provider.github
  to   = module.github_oidc["demo-service"].aws_iam_openid_connect_provider.github[0]
}

module "service_ecr" {
  for_each = local.services
  source   = "../../modules/ecr"

  repository_name      = each.value.name
  image_tag_mutability = "IMMUTABLE"

  tags = {
    Environment = "dev"
    Project     = "IDP-Infra"
    Service     = each.value.name
  }
}

module "github_oidc" {
  for_each = local.services
  source   = "../../modules/github-oidc"

  ecr_repository_arn   = module.service_ecr[each.key].repository_arn
  github_org           = each.value.github_owner
  github_repository    = each.value.github_repository
  github_branch        = each.value.github_branch
  create_oidc_provider = each.key == "demo-service"
  role_name            = "github-actions-${each.key}-ecr"

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

removed {
  from = helm_release.argocd

  lifecycle {
    destroy = false
  }
}

# Argo CD is installed in the cluster but temporarily unmanaged because Helm
# reported an operation already in progress. Uncomment this resource when
# Terraform should manage or recreate the release again.
# resource "helm_release" "argocd" {
#   name             = "argocd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   version          = "8.5.5"
#   namespace        = kubernetes_namespace.argocd.metadata[0].name
#   create_namespace = false
#   wait             = true
#   timeout          = 900
#
#   depends_on = [kubernetes_namespace.argocd]
# }

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.46.6"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.expander"
    value = "least-waste"
  }

  depends_on = [aws_iam_role_policy.cluster_autoscaler]
}