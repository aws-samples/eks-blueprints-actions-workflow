eks_admins_iam_role = "SharedServices"
vpc_id              = "vpc-0096c8b8cbc54dd73"
eks_public_subnet_ids = [
  "subnet-09937c47a25c532d8",
  "subnet-0c7fa226216f34c9c",
  "subnet-029ef29a271261efa"
]
eks_private_subnet_ids = [
  "subnet-0e0fb088632a7f001",
  "subnet-051cf8d7ea7f4a513",
  "subnet-08f2223dc60683710"
]
team_name                 = "pr"
environment               = "test"
cluster_id                = ""
region                    = "us-west-2"
eks_cluster_domain        = "micbegin.people.aws.dev"
acm_certificate_domain    = "*.micbegin.people.aws.dev"
workloads_org             = "aws-samples"
workloads_path            = "argocd"
workloads_repo_url        = "https://github.com/aws-samples/eks-blueprints-actions-workflow.git"
workloads_target_revision = "main"
