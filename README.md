# EKS Clusters using Karpenter on Fargate deployed with the Terraform EKS Blueprints and GitHub Actions Workflows

[![checkov](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/checkov.yml/badge.svg)](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/checkov.yml)
[![tflint](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/tflint.yml/badge.svg)](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/tflint.yml)
[![terraform-docs](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/terraform-docs.yml/badge.svg)](https://github.com/aws-samples/eks-blueprints-actions-workflow/actions/workflows/terraform-docs.yml)

> **Warning**
> You are responsible for the cost of the AWS services used while running this sample deployment. There is no additional cost for using this sample. For full details, see the pricing pages for each AWS service you will be using in this sample. Prices are subject to change.
> This sample code should only be used for demonstration purposes and should not be used in a production environment.

This example provides the following capabilities:

- Deploy EKS clusters with GitHub Action Workflows
- Execute test suites on ephemeral test clusters
- Leverage [Karpenter](https://karpenter.sh) for Autoscaling

The following resources will be deployed by this example.

- Creates EKS Cluster Control plane with one Fargate profile for the following namespaces:
  - kube-system
  - karpenter
  - argocd
- ArgoCD add-on deployed through a Helm chart
- Karpenter add-on deployed through a Helm chart
- One Karpenter default NodePool
- AWS Load Balancer Controller add-on deployed through a Helm chart
- External DNS add-on deployed through a Helm chart
- The [game-2048](helm/game-2048) application deployed through a Helm chart from this repository to demonstrates how Karpenter scales nodes based on workload requirements and how to configure the Ingress so that an application can be accessed over the internet.

## How to Deploy Manually

### Manual Deployment Prerequisites

Ensure that you have installed the following tools in your Linux, Mac or Windows Laptop before start working with this module and run Terraform Plan and Apply

- [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [kubectl](https://Kubernetes.io/docs/tasks/tools/)
- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

The following resources need to be available in the AWS accounts where you want to deploy EKS clusters:

- EKS Cluster Administrators IAM Role
- VPC with private and public subnets
- Route 53 hosted zone
- Wildcard certificate issued in ACM

You also need to provide a Terraform Cloud organization and workspace, and a [GitHub Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) (PAT) to access the application helm chart on this repository.

## Manual Deployment Steps

1. Clone the repo using the command below

    ```shell
    git clone https://github.com/aws-samples/eks-blueprints-actions-workflow.git
    ```

1. Run Terraform init to initialize a working directory with configuration files

    ```shell
    export TF_CLOUD_ORGANIZATION='<my-org>'
    export TF_WORKSPACE='<my-workspace>'
    export TF_TOKEN_app_terraform_io='<my-token>'

    terraform init
    ```

1. Create the tfvars file in the `envs` folder with the values for your EKS cluster.
    > Use [envs/dev/terraform.tfvars](envs/dev/terraform.tfvars) as a reference
    > Replace all values contained in the demo example with the required cluster configuration

1. Run Terraform plan to verify the resources created by this execution

    ```shell
    # Personal Access Token (PAT) required to access the application helm chart repo
    export WORKLOADS_PAT="<github_token>"

    terraform plan \
      -var-file="./envs/dev/terraform.tfvars" \
      -var="workloads_pat=${WORKLOADS_PAT}" \
      -out=tfplan
    ```

1. Finally, Terraform apply.

    ```shell
    terraform apply tfplan
    ```

## How to Deploy with a GitHub Actions Workflow

### GitHub Actions Workflow Prerequisites

The following resources need to be available in the AWS accounts where you want to deploy EKS clusters:

- EKS Cluster Administrators IAM Role
- VPC with private and public subnets
- Route 53 hosted zone
- Wildcard certificate issued in ACM
- [GitHub Actions IAM OIDC Identity Provider](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- GitHub Actions Terraform Execution IAM Role

Follow the instructions for [Local Execution mode configuration](https://github.com/aws-samples/aws-terraform-reusable-workflow?tab=readme-ov-file#local-execution-mode-configuration). You will need to provide a Terraform Cloud organization with one workspace per environment and a [GitHub Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) (PAT) to access the application helm chart on this repository.

Ensure that you all the required Actions Secrets are present in the [Secrets - Actions](https://github.com/aws-samples/eks-blueprints-actions-workflow/settings/secrets/actions) settings before creating a workflow to deploy an EKS cluster.

## Workflow Deployment Steps

1. Clone the repo using the command below

    ```shell
    git clone https://github.com/aws-samples/eks-blueprints-actions-workflow.git
    ```

1. Create a new repo into you own GitHub organization using the cloned repo.

1. Create a branch.

1. Create or update the tfvars file in the `envs` folder with the values for your EKS cluster.
    > Use [envs/dev/terraform.tfvars](envs/dev/terraform.tfvars) as a reference
    > Replace all values contained in the demo example with the required cluster configuration

1. Commit your changes and publish your branch.

1. Create a Pull Request. This will trigger the workflow and add a comment with the expected plan outcome to the PR. The Terraform Apply step will not be executed at this stage.

1. A workflow that triggers the deployment of an ephemeral cluster in the PR-TEST environment will be waiting for an approval. Add a required reviewer to approve workflow runs so you can decide when to deploy the ephemeral test cluster.

1. Ask someone to review the PR and make the appropriate changes if necessary.

1. Once the PR is approved and the code is merged to the main branch, the workflow will be triggered automatically and start the deploy job. The Terraform Apply step will only be executed if changes are required.

1. When the PR is closed, a workflow to destroy the ephemeral test cluster in the PR-TEST environment. Approve the workflow run to destroy the EKS cluster.

## Validation Steps

1. Configure kubectl.

    EKS Cluster details can be extracted from terraform output or from AWS Console to get the name of cluster. This following command used to update the `~/.kube/config` file in your local machine where you run kubectl commands to interact with your EKS Cluster.

    ```shell
    aws eks --region <region> update-kubeconfig --name <cluster-name>
    ```

1. Access the ArgoCD UI by running the following command:

    ```sh
    kubectl port-forward service/argocd-server -n argocd 8080:443
    ```

    Then, open your browser and navigate to [https://localhost:8080/](https://localhost:8080/)
    The username is `admin`.

    You can retrieve the `admin` user password by running the following command:

    ```sh
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

1. Click on the `REFRESH APPS` button and select all applications to deploy them.

1. After the game-2048 deployment is complete, you should see multiple Fargate nodes and five nodes provisioned by Karpenter up and running.

    ```shell
    kubectl get nodes
    ```

1. Check that the demo app workload is deployed on nodes provisioned by Karpenter provisioners.

    You can run this command to view the Karpenter Controller logs while the nodes are provisioned.

    ```shell
    kubectl logs --selector app.kubernetes.io/name=karpenter -n karpenter
    ```

1. After a couple of minutes, you should see new nodes being added by Karpenter to accommodate the game-2048 application EC2 instance family, capacity type, availability zones placement, and pod anti-affinity requirements.

    ```shell
    kubectl get node \
      --selector=karpenter.sh/initialized=true \
      -L karpenter.sh/provisioner-name \
      -L topology.kubernetes.io/zone \
      -L karpenter.sh/capacity-type \
      -L karpenter.k8s.aws/instance-family
    ```

1. Test by listing the game-2048 pods. You should see that all the pods are running on different nodes because of the pod anti-affinity rule.

    ```shell
    kubectl -n game-2048 get pods -o wide
    ```

1. Test that the sample application is now available.

    ```shell
    kubectl -n game-2048 get ingress/ingress-2048
    ```

    Open the browser to access the application via the ALB address `https://game-2048-<ClusterName>.<Domain>/`

    > **Warning**
    > You might need to wait a few minutes, and then refresh your browser.

## Cleanup Steps

  To clean up your environment, delete the sample workload and then destroy the rest of the Terraform resources.

  1. Run Terraform init to initialize a working directory with configuration files

      ```shell
      export TF_CLOUD_ORGANIZATION='<my-org>'
      export TF_WORKSPACE='<my-workspace>'
      export TF_TOKEN_app_terraform_io='<my-token>'

      terraform init
      ```

  1. Delete the Demo Game 2048 Application.

       ```shell
      kubectl -n argocd delete application game-2048
      ```

  1. Wait for 5 minutes to allow Karpenter to delete the empty nodes.

  1. Run Terraform destroy.

      ```shell
      # Personal Access Token (PAT) required to access the application helm chart repo
      export WORKLOADS_PAT="<github_token>"

      terraform destroy \
        -var-file="./envs/dev/terraform.tfvars" \
        -var="workloads_pat=${WORKLOADS_PAT}"
      ```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=5.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >=2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | github.com/terraform-aws-modules/terraform-aws-eks.git | 70866e6fb26aa46a876f16567a043a9aaee4ed34 |
| <a name="module_eks_blueprints_addons"></a> [eks\_blueprints\_addons](#module\_eks\_blueprints\_addons) | github.com/aws-ia/terraform-aws-eks-blueprints-addons.git | 257677adeed1be54326637cf919cf24df6ad7c06 |
| <a name="module_external_dns_irsa_role"></a> [external\_dns\_irsa\_role](#module\_external\_dns\_irsa\_role) | github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks | f0a3a1cf8ba2f43f7919ba29593be3e9cadd363c |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | github.com/terraform-aws-modules/terraform-aws-eks.git//modules/karpenter | 70866e6fb26aa46a876f16567a043a9aaee4ed34 |
| <a name="module_load_balancer_controller_irsa_role"></a> [load\_balancer\_controller\_irsa\_role](#module\_load\_balancer\_controller\_irsa\_role) | github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks | f0a3a1cf8ba2f43f7919ba29593be3e9cadd363c |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_tag.private_subnet_cluster_alb_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.private_subnet_cluster_karpenter_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_cluster_alb_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.vpc_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [helm_release.argocd_applications](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_subnet.eks_private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.eks_public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.eks_selected_private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.eks_selected_public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | Argo CD version | `string` | n/a | yes |
| <a name="input_aws_load_balancer_controller_version"></a> [aws\_load\_balancer\_controller\_version](#input\_aws\_load\_balancer\_controller\_version) | Version of the AWS Load Balancer Controller Helm Chart | `string` | n/a | yes |
| <a name="input_cluster_suffix"></a> [cluster\_suffix](#input\_cluster\_suffix) | The EKS Cluster suffix | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Control Plane version to be provisioned | `string` | n/a | yes |
| <a name="input_core_dns_version"></a> [core\_dns\_version](#input\_core\_dns\_version) | Version of the CoreDNS addon | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | The EKS cluster environment | `string` | n/a | yes |
| <a name="input_external_dns_version"></a> [external\_dns\_version](#input\_external\_dns\_version) | External DNS version | `string` | n/a | yes |
| <a name="input_karpenter_version"></a> [karpenter\_version](#input\_karpenter\_version) | Version of the Karpenter Helm Chart | `string` | n/a | yes |
| <a name="input_kube_proxy_version"></a> [kube\_proxy\_version](#input\_kube\_proxy\_version) | Version of the kube-proxy addon | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where to deploy the EKS Cluster | `string` | n/a | yes |
| <a name="input_route53_hosted_zone_id"></a> [route53\_hosted\_zone\_id](#input\_route53\_hosted\_zone\_id) | Route 53 Hosted Zone ID to be used by the external-dns addon | `string` | n/a | yes |
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | Route 53 Hosted Zone Domain Name to be used by the Demo Game 2048 Application Ingress | `string` | n/a | yes |
| <a name="input_tenant_name"></a> [tenant\_name](#input\_tenant\_name) | The EKS Cluster tenant name | `string` | n/a | yes |
| <a name="input_vpc_cni_version"></a> [vpc\_cni\_version](#input\_vpc\_cni\_version) | Version of the VPC CNI addon | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The name of the VPC where to deploy the EKS Cluster Worker Nodes | `string` | n/a | yes |
| <a name="input_workloads_org"></a> [workloads\_org](#input\_workloads\_org) | The Workloads GitHub Organization | `string` | n/a | yes |
| <a name="input_workloads_pat"></a> [workloads\_pat](#input\_workloads\_pat) | The Workloads GitHub Personnal Access Token | `string` | n/a | yes |
| <a name="input_workloads_repo_url"></a> [workloads\_repo\_url](#input\_workloads\_repo\_url) | The Workloads GitHub Repository URL | `string` | n/a | yes |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | EKS Access Entries | `map(any)` | `{}` | no |
| <a name="input_enable_endpoint_public_access"></a> [enable\_endpoint\_public\_access](#input\_enable\_endpoint\_public\_access) | Indicates whether or not the Amazon EKS public API server endpoint is enabled | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `map('BusinessUnit`,`XYZ`) | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl. Make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
<!-- END_TF_DOCS -->


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
