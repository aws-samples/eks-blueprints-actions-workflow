cluster_version    = "1.29"
vpc_cni_version    = "v1.17.1-eksbuild.1"
core_dns_version   = "v1.11.1-eksbuild.6"
kube_proxy_version = "v1.29.1-eksbuild.2"

argocd_version                       = "6.7.3"  # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/Chart.yaml
karpenter_version                    = "0.35.2" # https://gallery.ecr.aws/karpenter/karpenter
aws_load_balancer_controller_version = "v1.7.2" # https://artifacthub.io/packages/helm/aws/aws-load-balancer-controller
external_dns_version                 = "1.14.3" # https://github.com/kubernetes-sigs/external-dns/blob/master/charts/external-dns/Chart.yaml
