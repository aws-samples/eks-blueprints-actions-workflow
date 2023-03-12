data "aws_vpc" "eks" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "eks_selected_private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnets" "eks_selected_public_subnets" {
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

data "aws_subnet" "eks_private_subnets" {
  vpc_id   = data.aws_vpc.eks.id
  for_each = toset(data.aws_subnets.eks_selected_private_subnets.ids)
  id       = each.value
}
data "aws_subnet" "eks_public_subnets" {
  vpc_id   = data.aws_vpc.eks.id
  for_each = toset(data.aws_subnets.eks_selected_public_subnets.ids)
  id       = each.value
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_availability_zones" "available" {}

data "aws_iam_role" "eks_admins" {
  name = var.eks_admins_iam_role
}

data "aws_iam_policy" "eks_cni" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

data "aws_iam_policy" "eks_worker_node" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "ecr_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy" "instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
