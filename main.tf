provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

locals {
  name   = "eks-${var.team_name}-${var.environment}-${substr(var.cluster_id, 0, 10)}"
  region = var.region

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = basename(path.cwd)
    GithubRepo = "github.com/aws-samples/eks-blueprints-actions-workflow"
  }
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------
resource "random_password" "argocd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Argo requires the password to be bcrypt, we use custom provider of bcrypt,
# as the default bcrypt function generates diff for each terraform plan
resource "bcrypt_hash" "argo" {
  cleartext = random_password.argocd.result
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "argocd" {
  name                    = "${local.name}-argocd"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

module "eks_blueprints" {
  source             = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.17.0"
  cluster_name       = local.name
  cluster_version    = var.k8s_version
  vpc_id             = var.vpc_id
  private_subnet_ids = var.eks_private_subnet_ids

  #----------------------------------------------------------------------------------------------------------#
  # Security groups used in this module created by the upstream modules terraform-aws-eks (https://github.com/terraform-aws-modules/terraform-aws-eks).
  #   Upstream module implemented Security groups based on the best practices doc https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html.
  #   So, by default the security groups are restrictive. Users needs to enable rules for specific ports required for App requirement or Add-ons
  #   See the notes below for each rule used in these examples
  #----------------------------------------------------------------------------------------------------------#
  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    # Allows Control Plane Nodes to talk to Worker nodes on Karpenter ports.
    # This can be extended further to specific port based on the requirement for others Add-on e.g., metrics-server 4443, spark-operator 8080, etc.
    # Change this according to your security requirements if needed
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  # EKS FARGATE PROFILES
  # We recommend to have Fargate profiles to place your critical workloads and add-ons
  # Then rely on Karpenter to scale your workloads
  fargate_profiles = {
    # Providing compute for namespaces where core addons reside
    core_addons = {
      fargate_profile_name = "core-addons"
      fargate_profile_namespaces = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "argocd"
        },
        {
          namespace = "karpenter"
        },
        {
          namespace = "external-dns"
        }
      ]
      subnet_ids = var.eks_private_subnet_ids
    }
  }

  # Add karpenter.sh/discovery tag so that we can use this as securityGroupSelector in karpenter provisioner
  node_security_group_tags = {
    "karpenter.sh/discovery/${local.name}" = local.name
  }

  # Add Karpenter IAM role to the aws-auth config map to allow the controller to register the ndoes to the clsuter
  map_roles = [
    {
      rolearn  = aws_iam_role.karpenter.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes"
      ]
    },
    {
      rolearn  = data.aws_iam_role.eks_admins.arn
      username = "eks-admins"
      groups = [
        "system:masters"
      ]
    },
  ]

  platform_teams = {
    eks-admins = {
      users = [
        data.aws_iam_role.eks_admins.arn
      ]
    }
  }

  cluster_endpoint_private_access = true

}

# module "eks_blueprints_kubernetes_addons" {
#   depends_on = [module.eks_blueprints.fargate_profiles]

#   source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.17.0"

#   eks_cluster_id       = module.eks_blueprints.eks_cluster_id
#   eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
#   eks_oidc_provider    = module.eks_blueprints.oidc_provider
#   eks_cluster_version  = module.eks_blueprints.eks_cluster_version
#   eks_cluster_domain   = var.eks_cluster_domain

#   enable_argocd = true
#   # This example shows how to set default ArgoCD Admin Password using SecretsManager with Helm Chart set_sensitive values.
#   argocd_helm_config = {
#     version = var.argocd_version
#     values = [templatefile("${path.module}/argocd-values.yaml", {
#       workloads_org      = var.workloads_org
#       workloads_pat      = var.workloads_pat
#       workloads_repo_url = var.workloads_repo_url
#     })]
#     set_sensitive = [
#       {
#         name  = "configs.secret.argocdServerAdminPassword"
#         value = bcrypt_hash.argo.id
#       }
#     ]
#   }

#   argocd_applications = {
#     workloads = {
#       path            = var.workloads_path
#       repo_url        = var.workloads_repo_url
#       target_revision = var.workloads_target_revision
#       values = {
#         spec = {
#           source = {
#             repoURL        = var.workloads_repo_url
#             targetRevision = var.workloads_target_revision
#           }
#           clusterName = local.name
#           ingress = {
#             host = var.eks_cluster_domain
#           }
#         }
#       }
#       add_on_application = false
#     }
#   }

#   enable_amazon_eks_vpc_cni = true
#   amazon_eks_vpc_cni_config = {
#     addon_version = var.vpc_cni_version
#   }

#   enable_amazon_eks_kube_proxy = true
#   amazon_eks_kube_proxy_config = {
#     addon_version = var.kube_proxy_version
#   }

#   remove_default_coredns_deployment = true
#   enable_self_managed_coredns       = true
#   self_managed_coredns_helm_config = {
#     # Sets the correct annotations to ensure the Fargate provisioner is used and not the EC2 provisioner
#     compute_type       = "fargate"
#     kubernetes_version = module.eks_blueprints.eks_cluster_version
#   }

#   enable_coredns_cluster_proportional_autoscaler = true
#   coredns_cluster_proportional_autoscaler_helm_config = {
#     version = var.cluster_proportional_autoscaler_version
#   }

#   enable_karpenter = true
#   karpenter_helm_config = {
#     version = var.karpenter_version
#   }

#   enable_aws_load_balancer_controller = true
#   aws_load_balancer_controller_helm_config = {
#     version = var.aws_load_balancer_controller_version
#     set_values = [
#       {
#         name  = "vpcId"
#         value = var.vpc_id
#       },
#       {
#         name  = "podDisruptionBudget.maxUnavailable"
#         value = 1
#       }
#     ]
#   }

#   enable_external_dns = true
#   external_dns_helm_config = {
#     version = var.external_dns_version
#   }

#   tags = local.tags
# }

# Add the Karpenter Provisioners IAM Role
# https://karpenter.sh/v0.19.0/getting-started/getting-started-with-terraform/#create-the-karpentercontroller-iam-role
resource "aws_iam_role" "karpenter" {
  name = "${local.name}-karpenter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_cni" {
  role       = aws_iam_role.karpenter.name
  policy_arn = data.aws_iam_policy.eks_cni.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_worker_node" {
  role       = aws_iam_role.karpenter.name
  policy_arn = data.aws_iam_policy.eks_worker_node.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_ecr_read_only" {
  role       = aws_iam_role.karpenter.name
  policy_arn = data.aws_iam_policy.ecr_read_only.arn
}

resource "aws_iam_role_policy_attachment" "karpenter_instance_core" {
  role       = aws_iam_role.karpenter.name
  policy_arn = data.aws_iam_policy.instance_core.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "${local.name}-karpenter-instance-profile"
  role = aws_iam_role.karpenter.name
}

# Add the default provisioner for Karpenter autoscaler
data "kubectl_path_documents" "karpenter_provisioners" {
  pattern = "${path.module}/manifests/default_provisioner*.yaml"
  vars = {
    azs                     = join(",", local.azs)
    iam-instance-profile-id = "${local.name}-karpenter-instance-profile"
    eks-cluster-id          = local.name
  }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  # depends_on = [module.eks_blueprints_kubernetes_addons]
  for_each  = toset(data.kubectl_path_documents.karpenter_provisioners.documents)
  yaml_body = each.value
}

resource "aws_ec2_tag" "vpc_tag" {
  resource_id = var.vpc_id
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_cluster_alb_tag" {
  for_each    = toset(var.eks_private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_cluster_karpenter_tag" {
  for_each    = toset(var.eks_private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery/${local.name}"
  value       = local.name
}

resource "aws_ec2_tag" "public_subnet_cluster_alb_tag" {
  for_each    = toset(var.eks_public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "shared"
}
