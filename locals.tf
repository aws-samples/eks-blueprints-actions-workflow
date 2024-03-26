locals {
  name = "eks-${var.tenant_name}-${var.environment}-${var.cluster_suffix}"

  private_subnet_ids = [for subnet in data.aws_subnet.eks_private_subnets : subnet.id]
  public_subnet_ids  = [for subnet in data.aws_subnet.eks_public_subnets : subnet.id]

  tags = {
    Blueprint  = basename(path.cwd)
    GithubRepo = "github.com/aws-samples/eks-blueprints-actions-workflow"
  }

  eks_tags = merge(var.tags,
    {
      "karpenter.sh/discovery/${local.name}" = local.name
    }
  )

  access_entries = {
    for key, value in var.access_entries : key => {
      kubernetes_groups   = try(value.kubernetes_groups, [])
      principal_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${value.role_name}"
      policy_associations = value.policy_associations
    }
  }
}
