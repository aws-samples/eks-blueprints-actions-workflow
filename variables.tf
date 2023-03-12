variable "k8s_version" {
  type        = string
  description = "Kubernetes version"
}

variable "vpc_cni_version" {
  type        = string
  description = "VPC CNI add-on version"
}

variable "kube_proxy_version" {
  type        = string
  description = "Kube Proxy add-on version"
}

variable "cluster_proportional_autoscaler_version" {
  type        = string
  description = "Cluster Proportional Autoscaler version"
}

variable "karpenter_version" {
  type        = string
  description = "Karpenter version"
}

variable "argocd_version" {
  type        = string
  description = "Argo CD version"
}

variable "aws_load_balancer_controller_version" {
  type        = string
  description = "AWS Load Balancer Controller version"
}

variable "external_dns_version" {
  type        = string
  description = "External DNS version"
}

variable "eks_admins_iam_role" {
  type        = string
  description = "The EKS Admins IAM Role Name"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC where to deploy the EKS Cluster Worker Nodes"
}

variable "team_name" {
  type        = string
  description = "The name of the team that will own EKS Cluster"
}

variable "environment" {
  type        = string
  description = "The environment of EKS Cluster"
}

variable "cluster_id" {
  type        = string
  description = "The EKS Cluster ID"
}

variable "region" {
  type        = string
  description = "The AWS region where to deploy the EKS Cluster"
}

variable "eks_cluster_domain" {
  type        = string
  description = "Route53 domain for the cluster."
}

variable "workloads_org" {
  type        = string
  description = "The Workloads GitHub Organization"
}

variable "workloads_pat" {
  type        = string
  description = "The Workloads GitHub Personnal Access Token"
}

variable "workloads_path" {
  type        = string
  description = "The Workloads Helm Chart Path"
}

variable "workloads_repo_url" {
  type        = string
  description = "The Workloads GitHub Repository URL"
}

variable "workloads_target_revision" {
  type        = string
  description = "The Workloads Git Repository Target Revision (Tag or Branch)"
  default     = "main"
}
