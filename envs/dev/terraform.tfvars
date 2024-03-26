environment                   = "dev"
cluster_suffix                = "01"
vpc_name                      = "eks-vpc"
region                        = "us-west-2"
tenant_name                   = "demo"
enable_endpoint_public_access = true

route53_hosted_zone_id   = "Z0053446TEDTI1D9V3U9"
route53_hosted_zone_name = "micbegin.people.aws.dev"

access_entries = {
  admins = {
    role_name = "eks-admins"
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          namespaces = []
          type       = "cluster"
        }
      }
    }
  }
}

workloads_org      = "aws-samples"
workloads_repo_url = "https://github.com/aws-samples/eks-blueprints-actions-workflow.git"
