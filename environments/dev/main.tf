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

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
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

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "github-actions"
    ManagedBy = "Terraform"
  }
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
  create_oidc_provider = false
  oidc_provider_arn    = aws_iam_openid_connect_provider.github_actions.arn
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

# --- Observability platform: Prometheus + OpenTelemetry Collector ---------

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.5.1"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      grafana = {
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            searchNamespace = "ALL"
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.111.1"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      mode             = "deployment"
      fullnameOverride = "otel-collector"
      image = {
        repository = "otel/opentelemetry-collector-contrib"
      }
      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }
        processors = {
          memory_limiter = {
            check_interval         = "5s"
            limit_percentage       = 80
            spike_limit_percentage = 25
          }
          batch = {}
        }
        exporters = {
          prometheus = {
            endpoint = "0.0.0.0:8889"
            resource_to_telemetry_conversion = {
              enabled = true
            }
          }
        }
        service = {
          pipelines = {
            traces = null
            logs   = null
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["prometheus"]
            }
          }
        }
      }
      ports = {
        otlp = {
          enabled       = true
          containerPort = 4317
          servicePort   = 4317
          protocol      = "TCP"
        }
        "otlp-http" = {
          enabled       = true
          containerPort = 4318
          servicePort   = 4318
          protocol      = "TCP"
        }
        prometheus = {
          enabled       = true
          containerPort = 8889
          servicePort   = 8889
          protocol      = "TCP"
        }
        "jaeger-compact" = { enabled = false }
        "jaeger-thrift"  = { enabled = false }
        "jaeger-grpc"    = { enabled = false }
        zipkin           = { enabled = false }
      }
      service = {
        type = "ClusterIP"
      }
      serviceMonitor = {
        enabled = true
        metricsEndpoints = [
          { port = "prometheus" }
        ]
      }
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "grafana_dashboard_java_service" {
  metadata {
    name      = "grafana-dashboard-java-service"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "java-service.json" = file("${path.module}/dashboards/java-service.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# --- Ingress: AWS Load Balancer Controller + Metrics Server ---------------

data "aws_iam_policy_document" "alb_controller_assume_role" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.11.0"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  depends_on = [aws_iam_role_policy_attachment.alb_controller]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.12.2"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  depends_on = [module.eks]
}