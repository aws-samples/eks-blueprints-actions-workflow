# EKS Clusters using Karpenter on Fargate deployed with the Terraform EKS Blueprints and GitHub Actions Workflows

> **Warning**
> You are responsible for the cost of the AWS services used while running this sample deployment. There is no additional cost for using this sample. For full details, see the pricing pages for each AWS service you will be using in this sample. Prices are subject to change.
> This sample code should only be used for demonstration purposes and should not be used in a production environment.

This example provides the following capabilities:

- Deploy EKS clusters with GitHub Action Workflows
- Execute test suites on ephemeral test clusters
- Leverage [Karpenter](karpenter.sh) for Autoscaling

The following resources will be deployed by this example.

- Creates EKS Cluster Control plane with one Fargate profile for the following namespaces:
  - kube-system
  - karpenter
  - argocd
  - external-dns
- Karpenter add-on deployed through a Helm chart
- One Karpenter default provisioner
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
- VPC with private and public subnets with the appropriate [elb tags](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html#:~:text=Your%20public%20and,tags%20aren%27t%20required.)
- Route 53 hosted zone
- Wildcard certificate issued in ACM
- S3 bucket where to store the Terraform state

You also need to provide a [GitHub Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) (PAT) to access the application helm chart on this repository.

## Manual Deployment Steps

1. Clone the repo using the command below

    ```shell
    git clone https://github.com/aws-samples/eks-blueprints-actions-workflow.git
    ```

1. Run Terraform init to initialize a working directory with configuration files

    ```shell
    export S3_BUCKET_NAME="<BucketName>"
    export CLUSTER_NAME="<BucketKey>"
    export AWS_REGION="us-west-2"
    export CLUSTER_ID="01"
    export ENVIRONMENT="dev"
    export TEAM_NAME="demo"

    terraform init \
      -backend-config="bucket=${S3_BUCKET_NAME}" \
      -backend-config="key=${CLUSTER_NAME}/tfstate" \
      -backend-config="region=${AWS_REGION}"
    ```

1. Create a tfvars file in the clusters folder with the values for your EKS cluster.
    > Use [clusters/demo-dev-01.tfvars](clusters/demo-dev-01.tfvars) as a reference
    > Replace all values contained in the demo example with the required cluster configuration

1. Run Terraform plan to verify the resources created by this execution

    ```shell
    # Personal Access Token (PAT) required to access the application helm chart repo
    export WORKLOADS_PAT="<github_token>"

    terraform plan \
      -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
      -var="region=${AWS_REGION}" \
      -var="cluster_id=${CLUSTER_ID}" \
      -var="environment=${ENVIRONMENT}" \
      -var="team_name=${TEAM_NAME}" \
      -var="workloads_pat=${WORKLOADS_PAT}" \
      -out=tfplan
    ```

1. Finally, Terraform apply.

    ```shell
    terraform apply tfplan
    ```

## Manual Destroy Steps

  To clean up your environment, delete the sample workload and then destroy the Terraform modules in reverse order.

  1. Run Terraform init to initialize a working directory with configuration files

      ```shell
      export S3_BUCKET_NAME="<BucketName>"
      export CLUSTER_NAME="<BucketKey>"
      export AWS_REGION="us-west-2"
      export CLUSTER_ID="01"
      export ENVIRONMENT="dev"
      export TEAM_NAME="demo"

      terraform init \
        -backend-config="bucket=${S3_BUCKET_NAME}" \
        -backend-config="key=${CLUSTER_NAME}/tfstate" \
        -backend-config="region=${AWS_REGION}"
      ```

  1. Run Terraform destroy to Destroy Argo CD, Karpenter Provisioner and IAM Role, Kubernetes Add-ons, and EKS cluster.

      ```shell
      # Argo CD
      terraform destroy \
        -target="module.eks_blueprints_kubernetes_addons.module.argocd" \
        -target="aws_secretsmanager_secret.argocd" \
        -target="bcrypt_hash.argo" \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      # Wait for 1-2 minutes to allow Karpenter to delete the empty nodes
      # Karpenter Provisioner
      terraform destroy \
        -target="kubectl_manifest.karpenter_provisioner" \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      # Kubernetes Add-Ons
      terraform destroy \
        -target="module.eks_blueprints_kubernetes_addons" \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      # EKS Cluster
      terraform destroy \
        -target="module.eks_blueprints" \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      # Karpenter IAM Role
      terraform destroy \
        -target="aws_iam_role.karpenter" \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      # VPC & Subnets Tags
      terraform destroy \
        -target="aws_ec2_tag.private_subnet_cluster_karpenter_tag" \
        -target="aws_ec2_tag.vpc_tag " \
        -var-file="./clusters/${CLUSTER_NAME}.tfvars" \
        -var="region=${AWS_REGION}" \
        -var="cluster_id=${CLUSTER_ID}" \
        -var="environment=${ENVIRONMENT}" \
        -var="team_name=${TEAM_NAME}" \
        -var="workloads_pat=${WORKLOADS_PAT}" \
        -auto-approve
      ```

## How to Deploy with a GitHub Actions Workflow

### GitHub Actions Workflow Prerequisites

The following resources need to be available in the AWS accounts where you want to deploy EKS clusters:

- EKS Cluster Administrators IAM Role
- VPC with private and public subnets with the appropriate [elb tags](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html#:~:text=Your%20public%20and,tags%20aren%27t%20required.)
- Route 53 hosted zone
- Wildcard certificate issued in ACM
- S3 bucket where to store the Terraform state
- [GitHub Actions IAM OIDC Identity Provider](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- GitHub Actions IAM Role with the [EKS Blueprints Minimum IAM policy](https://aws-ia.github.io/terraform-aws-eks-blueprints/latest/iam/minimum-iam-policy/)

Ensure that you all the required Actions Secrets are present in the [Secrets - Actions](https://github.com/mlseoperations/aws-acc-digitallabsdev-eks/settings/secrets/actions) settings before creating a workflow to deploy an EKS cluster.

For example, to deploy a cluster in two environments named Dev and Staging you will need the following [GitHub Actions Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets):

- DEMO_WORKLOADS_PAT
- DEV_AWS_ACCOUNT
- DEV_AWS_IAM_ROLE
- STAGING_AWS_ACCOUNT
- STAGING_AWS_IAM_ROLE

Create the Environments you want to manage in your GtiHub repository. This example uses the following [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment):

- DEV
- TEST
- PR-TEST

## Workflow Deployment Steps

1. Clone the repo using the command below

    ```shell
    git clone https://github.com/aws-samples/eks-blueprints-actions-workflow.git
    ```

1. Create a new repo into you own GitHub organization using the cloned repo.
1. Create a branch.
1. If it doesn't exist already, Create a `.yml` file in the [.github/workflows](.github/workflows) folder containing the information required by the cluster you want to deploy:
    > Use [.github/workflows/terraform-deploy-eks-demo-01.yml](.github/workflows/terraform-deploy-eks-demo-01.yml) as a reference
    > Replace all values contained in the demo example with the required cluster configuration

1. If it doesn't exist already, create the tfvars files in the clusters folder with the values for your EKS clusters.
    > Use [clusters/demo-dev-01.tfvars](clusters/demo-dev-01.tfvars) as a reference
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

1. You can access the ArgoCD UI by running the following command:

    ```sh
    kubectl port-forward svc/argo-cd-argocd-server 8080:443 -n argocd
    ```

    Then, open your browser and navigate to `https://localhost:8080/`
    Username should be `admin`.

    The password will be the generated password by `random_password` resource, stored in AWS Secrets Manager.
    You can easily retrieve the password by running the following command:

    ```sh
    aws secretsmanager get-secret-value --secret-id <SECRET_NAME> --region <REGION>
    ```

    Replace `<SECRET_NAME>` with the name of the secret name, if you haven't changed it then it should be `argocd`, also, make sure to replace `<REGION>` with the region you are using.

    Pickup the the secret from the `SecretString`.

1. List all the worker nodes. You should see a multiple fargate nodes and one node provisioned by Karpenter up and running

    ```shell
    kubectl get nodes
    ```

1. List all the pods running in karpenter namespace

    ```shell
    kubectl get pods -n karpenter
    ```

1. List the karpenter provisioner deployed.

    ```shell
    kubectl get provisioners
    ```

1. Check that the demo app workload is deployed on nodes provisioned by Karpenter provisioners.

    You can run this command to view the Karpenter Controller logs while the nodes are provisioned.

    ```shell
    kubectl logs --selector app.kubernetes.io/name=karpenter -n karpenter
    ```

1. After a couple of minutes, you should see new nodes being added by Karpenter to accommodate the game-2048 application EC2 instance family, capacity type, availability zones placement, and pod anti-affinity requirements.

    > **Warning**
    > Because of [known limitations with topology spread](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#known-limitations), the pods might not evenly spread through availability zones.

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
    kubectl get pods -o wide
    ```

1. Test that the sample application is now available.

    ```shell
    kubectl get ingress/ingress-2048 -n game-2048
    ```

    Open the browser to access the application via the ALB address `https://game-2048-<ClusterName>.<Domain>/`

    > **Warning**
    > You might need to wait a few minutes, and then refresh your browser.

## Workflow Destroy Steps

1. Create a branch.
1. Create a `.yml` file in the [.github/workflows](.github/workflows) folder containing the information required by the cluster you want to destroy:
    > Use [.github/workflows/terraform-destroy-eks-demo-01.yml](.github/workflows/terraform-destroy-eks-demo-01.yml) as a reference
    > Replace all values contained in the demo example with the required cluster configuration

1. Commit your changes and publish your branch.
1. Create a Pull Request. This will trigger the workflow and add a comment with the expected plan outcome to the PR. The Terraform Destroy step will not be executed at this stage.
1. Ask someone to review the PR and make the appropriate changes if necessary.
1. Once the PR is approved and the code is merged to the main branch, the workflow will have to be triggered manually to start the destroy job.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.72 |
| <a name="requirement_bcrypt"></a> [bcrypt](#requirement\_bcrypt) | >= 0.1.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.4.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.47.0 |
| <a name="provider_bcrypt"></a> [bcrypt](#provider\_bcrypt) | 0.1.2 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.14.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.3.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints"></a> [eks\_blueprints](#module\_eks\_blueprints) | github.com/aws-ia/terraform-aws-eks-blueprints | v4.17.0 |
| <a name="module_eks_blueprints_kubernetes_addons"></a> [eks\_blueprints\_kubernetes\_addons](#module\_eks\_blueprints\_kubernetes\_addons) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons | v4.17.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_tag.private_subnet_cluster_alb_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.private_subnet_cluster_karpenter_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_cluster_alb_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.vpc_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_iam_instance_profile.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.karpenter_ecr_read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_eks_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_eks_worker_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_key.argocd_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret.argocd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.argocd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [bcrypt_hash.argo](https://registry.terraform.io/providers/viktorradnai/bcrypt/latest/docs/resources/hash) | resource |
| [kubectl_manifest.karpenter_provisioner](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [random_password.argocd](https://registry.terraform.io/providers/hashicorp/random/3.3.2/docs/resources/password) | resource |
| [aws_acm_certificate.issued](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/acm_certificate) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy.ecr_read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.eks_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.eks_worker_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_role.eks_admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_secretsmanager_secret_version.admin_password_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_subnet.eks_private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.eks_public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.eks_selected_private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.eks_selected_public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [kubectl_path_documents.karpenter_provisioners](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/data-sources/path_documents) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_domain"></a> [acm\_certificate\_domain](#input\_acm\_certificate\_domain) | Route53 certificate domain | `string` | n/a | yes |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | Argo CD version | `string` | n/a | yes |
| <a name="input_aws_load_balancer_controller_version"></a> [aws\_load\_balancer\_controller\_version](#input\_aws\_load\_balancer\_controller\_version) | AWS Load Balancer Controller version | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | The EKS Cluster ID | `string` | n/a | yes |
| <a name="input_cluster_proportional_autoscaler_version"></a> [cluster\_proportional\_autoscaler\_version](#input\_cluster\_proportional\_autoscaler\_version) | Cluster Proportional Autoscaler version | `string` | n/a | yes |
| <a name="input_eks_admins_iam_role"></a> [eks\_admins\_iam\_role](#input\_eks\_admins\_iam\_role) | The EKS Admins IAM Role Name | `string` | n/a | yes |
| <a name="input_eks_cluster_domain"></a> [eks\_cluster\_domain](#input\_eks\_cluster\_domain) | Route53 domain for the cluster. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment of EKS Cluster | `string` | n/a | yes |
| <a name="input_external_dns_version"></a> [external\_dns\_version](#input\_external\_dns\_version) | External DNS version | `string` | n/a | yes |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | Kubernetes version | `string` | n/a | yes |
| <a name="input_karpenter_version"></a> [karpenter\_version](#input\_karpenter\_version) | Karpenter version | `string` | n/a | yes |
| <a name="input_kube_proxy_version"></a> [kube\_proxy\_version](#input\_kube\_proxy\_version) | Kube Proxy add-on version | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where to deploy the EKS Cluster | `string` | n/a | yes |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | The name of the team that will own EKS Cluster | `string` | n/a | yes |
| <a name="input_vpc_cni_version"></a> [vpc\_cni\_version](#input\_vpc\_cni\_version) | VPC CNI add-on version | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The name of the VPC where to deploy the EKS Cluster Worker Nodes | `string` | n/a | yes |
| <a name="input_workloads_org"></a> [workloads\_org](#input\_workloads\_org) | The Workloads GitHub Organization | `string` | n/a | yes |
| <a name="input_workloads_pat"></a> [workloads\_pat](#input\_workloads\_pat) | The Workloads GitHub Personnal Access Token | `string` | n/a | yes |
| <a name="input_workloads_path"></a> [workloads\_path](#input\_workloads\_path) | The Workloads Helm Chart Path | `string` | n/a | yes |
| <a name="input_workloads_repo_url"></a> [workloads\_repo\_url](#input\_workloads\_repo\_url) | The Workloads GitHub Repository URL | `string` | n/a | yes |
| <a name="input_workloads_target_revision"></a> [workloads\_target\_revision](#input\_workloads\_target\_revision) | The Workloads Git Repository Target Revision (Tag or Branch) | `string` | `"main"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS Cluster Name |
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
<!-- END_TF_DOCS -->


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
