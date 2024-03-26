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

data "aws_caller_identity" "current" {}
