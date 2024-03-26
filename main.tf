################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source = "github.com/terraform-aws-modules/terraform-aws-eks.git?ref=70866e6fb26aa46a876f16567a043a9aaee4ed34" #--> v20.8.4

  cluster_name    = local.name
  cluster_version = var.cluster_version

  enable_cluster_creator_admin_permissions = true

  vpc_id                          = data.aws_vpc.eks.id
  subnet_ids                      = local.private_subnet_ids
  control_plane_subnet_ids        = local.private_subnet_ids
  cluster_endpoint_public_access  = var.enable_endpoint_public_access
  cluster_endpoint_private_access = true

  create_cloudwatch_log_group = true
  cluster_enabled_log_types   = ["audit", "api", "authenticator"]

  cluster_addons = {
    coredns = {
      addon_version = var.core_dns_version
      configuration_values = jsonencode({
        computeType = "fargate"
        # Ensure that we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }

    kube-proxy = {
      addon_version = var.kube_proxy_version
    }

    vpc-cni = {
      addon_version = var.vpc_cni_version
    }
  }

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    argocd = {
      selectors = [
        { namespace = "argocd" }
      ]
    }
  }

  access_entries = local.access_entries

  tags = local.eks_tags
}


################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints-addons.git?ref=257677adeed1be54326637cf919cf24df6ad7c06" #--> v1.16.1

  depends_on        = [module.eks]
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_argocd = true
  argocd = {
    name          = "argocd"
    chart_version = var.argocd_version
    repository    = "https://argoproj.github.io/argo-helm"
    namespace     = "argocd"
    values = [templatefile("${path.module}/helm/argocd-values.yaml",
      {
        environment        = var.environment
        workloads_org      = var.workloads_org
        workloads_pat      = var.workloads_pat
        workloads_repo_url = var.workloads_repo_url
      }
    )]
  }

  tags = var.tags
}

resource "helm_release" "argocd_applications" {
  depends_on       = [module.eks_blueprints_addons]
  namespace        = "argocd"
  create_namespace = false
  name             = "argocd-apps"
  chart            = "argocd"

  values = [
    yamlencode({
      spec = { source = { targetRevision = "feature/eks-1.29" } }
    }),
    yamlencode({
      clusterName     = module.eks.cluster_name
      clusterEndpoint = module.eks.cluster_endpoint
      vpcId           = data.aws_vpc.eks.id
    }),
    yamlencode({
      karpenter = {
        version           = var.karpenter_version
        interruptionQueue = module.karpenter.queue_name
        iamRoleArn        = module.karpenter.iam_role_arn
        iamRoleName       = module.karpenter.node_iam_role_name
      }
    }),
    yamlencode({
      awsLoadBalancerController = {
        version    = var.aws_load_balancer_controller_version
        iamRoleArn = module.load_balancer_controller_irsa_role.iam_role_arn
      }
    }),
    yamlencode({
      externalDns = {
        version    = var.external_dns_version
        iamRoleArn = module.external_dns_irsa_role.iam_role_arn
      }
    }),
    yamlencode({
      game2048 = {
        ingress = {
          host = var.route53_hosted_zone_name
        }
      }
    }),
  ]
}

################################################################################
# Karpenter Resources
################################################################################

module "karpenter" {
  source = "github.com/terraform-aws-modules/terraform-aws-eks.git//modules/karpenter?ref=70866e6fb26aa46a876f16567a043a9aaee4ed34" #--> v20.8.4

  cluster_name = module.eks.cluster_name

  # EKS Fargate currently does not support Pod Identity
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

################################################################################
# Addons IRSA
################################################################################

module "load_balancer_controller_irsa_role" {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=f0a3a1cf8ba2f43f7919ba29593be3e9cadd363c" #--> v5.37.2

  role_name                              = "${local.name}-load-balancer-controller-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

module "external_dns_irsa_role" {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=f0a3a1cf8ba2f43f7919ba29593be3e9cadd363c" #--> v5.37.2

  role_name                     = "${local.name}-external-dns-irsa"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = local.tags
}

################################################################################
# VPC & Subnets Tags
################################################################################

resource "aws_ec2_tag" "vpc_tag" {
  resource_id = data.aws_vpc.eks.id
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_cluster_alb_tag" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_cluster_karpenter_tag" {
  for_each    = toset(local.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery/${local.name}"
  value       = local.name
}

resource "aws_ec2_tag" "public_subnet_cluster_alb_tag" {
  for_each    = toset(local.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}
