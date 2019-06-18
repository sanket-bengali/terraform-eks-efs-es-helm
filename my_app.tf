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
module "my_app_eks_setup" {
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
