variable "region" {
  type        = string
  description = "The AWS region where to deploy the EKS Cluster"
}

variable "tenant_name" {
  type        = string
  description = "The EKS Cluster tenant name"
}

variable "environment" {
  type        = string
  description = "The EKS cluster environment"
}

variable "cluster_suffix" {
  type        = string
  description = "The EKS Cluster suffix"
}

variable "cluster_version" {
  description = "EKS Control Plane version to be provisioned"
  type        = string
}

variable "tags" {
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
  type        = map(string)
  default     = {}
}

variable "argocd_version" {
  type        = string
  description = "Argo CD version"
}

variable "external_dns_version" {
  type        = string
  description = "External DNS version"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC where to deploy the EKS Cluster Worker Nodes"
}

variable "workloads_org" {
  type        = string
  description = "The Workloads GitHub Organization"
}

variable "workloads_pat" {
  type        = string
  description = "The Workloads GitHub Personnal Access Token"
}

variable "workloads_repo_url" {
  type        = string
  description = "The Workloads GitHub Repository URL"
}

variable "enable_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "karpenter_version" {
  description = "Version of the Karpenter Helm Chart"
  type        = string
}

variable "access_entries" {
  description = "EKS Access Entries"
  type        = map(any)
  default     = {}
}

variable "core_dns_version" {
  description = "Version of the CoreDNS addon"
  type        = string
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon"
  type        = string
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI addon"
  type        = string
}

variable "aws_load_balancer_controller_version" {
  description = "Version of the AWS Load Balancer Controller Helm Chart"
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "Route 53 Hosted Zone ID to be used by the external-dns addon"
  type        = string
}

variable "route53_hosted_zone_name" {
  type        = string
  description = "Route 53 Hosted Zone Domain Name to be used by the Demo Game 2048 Application Ingress"
}
