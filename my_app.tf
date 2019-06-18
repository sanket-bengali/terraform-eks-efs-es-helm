module "my_app_eks_setup" {
  source                        = "/path/to/module/my-app-eks-setup"
  namespace                     = "${var.namespace}"
  cluster_name                  = "${module.cluster_label.id}"
  cluster_endpoint              = "${module.eks_cluster.eks_cluster_endpoint}"
  kubeconfig                    = "${module.eks_workers.kubeconfig}"
  kubeconfig_filename           = "${local.kubeconfig_filename}"
  cluster_ca_certificate        = "${base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)}"
  #token                         = "${module.eks_cluster.aws_authenticator_token}"
  domain_endpoint               = "${module.elasticsearch.domain_endpoint}"
  aws_iam_role                  = "${module.eks_workers.worker_role_arn}"

  efs_id                        = "${module.efs.id}"
  region                        = "${var.region}"
}
