# Terraform sample solution to deploy distributed, cloud-native application on AWS

[Cloudposse](https://github.com/cloudposse) have a huge list of open-sourced Terraform modules for AWS.

Those modules can be used as plug-and-play to create and manage various AWS resources for an application.

For this sample solution, below modules are used :

[Label](https://github.com/cloudposse/terraform-terraform-label)

[VPC](https://github.com/cloudposse/terraform-aws-vpc)

[Subnet](https://github.com/cloudposse/terraform-aws-dynamic-subnets)

[EFS](https://github.com/cloudposse/terraform-aws-efs)

[EKS cluster](https://github.com/cloudposse/terraform-aws-eks-cluster)

[EKS workers](https://github.com/cloudposse/terraform-aws-eks-workers)

[EC2 auto-scaling group](https://github.com/cloudposse/terraform-aws-ec2-autoscale-group)

[Elasticsearch](https://github.com/cloudposse/terraform-aws-elasticsearch)

#### NOTE : This sample solution includes an additional module called "my-app-eks-setup" that is used to setup and configure Kubernetes after EKS cluster is deployed, and then install Helm charts on top of that.

#### In the terraform code for deploying a complete application on AWS, these modules are executed (parallel or sequential, based on their dependencies) from a "root module" (for ex. "my_app.tf").

### High-level flow of the modules deployment :

##### NOTE : This diagram is mainly focused on Kubernetes and Helm configuration and deployments. Hence, does not include common modules and resources like Label, VPC, subnets, security groups, IAM roles etc.

![Alt text](https://github.com/sanket-bengali/terraform-eks-efs-es-helm/blob/master/images/tf-eks-efs-es-helm-images.png)


In the my_app.tf module, which is the "root module" that executes other modules need to have module "my-app-eks-setup" to execute the above mentioned flow in addition to other modules :

```
provider "aws" {
  ...
}
module "label" {
  ...
}
module "vpc" {
  ...
}
module "eks-cluster" {
  ...
}
.....
.....
locals {
  kubeconfig_filename          = "${path.module}/kubeconfig${var.delimiter}${module.eks_cluster.eks_cluster_id}.yaml"
}
module "my-app-eks-setup" {
  source                        = "/path/to/module/my-app-eks-setup"
  namespace                     = "${var.namespace}"
  
  # EKS cluster name and endpoint
  cluster_name                  = "${module.cluster_label.id}"
  cluster_endpoint              = "${module.eks_cluster.eks_cluster_endpoint}"
  
  kubeconfig                    = "${module.eks_workers.kubeconfig}"
  kubeconfig_filename           = "${local.kubeconfig_filename}"
  cluster_ca_certificate        = "${base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)}"
  # If generated token is used for Kubernetes and/or Helm providers
  #token                         = "${module.eks_cluster.aws_authenticator_token}"
  aws_iam_role                  = "${module.eks_workers.worker_role_arn}"
  
  # Elasticsearch domain endpoint
  domain_endpoint               = "${module.elasticsearch.domain_endpoint}"
  
  # Helm chart params for efs-provisioner
  efs_id                        = "${module.efs.id}"
  region                        = "${var.region}"
}
.....
```

## More information

[Deploying a distributed, cloud-native system on AWS using Terraform](https://medium.com/@sanketbengali.23/deploying-a-distributed-containerized-system-on-aws-using-terraform-674ad20b4f97)

## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.
