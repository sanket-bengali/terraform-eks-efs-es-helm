resource "local_file" "kubeconfig" {
  content  = "${var.kubeconfig}"
  filename = "${var.kubeconfig_filename}"
}

provider "kubernetes" {
  cluster_ca_certificate = "${var.cluster_ca_certificate}"
  host                   = "${var.cluster_endpoint}"
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args        = ["token", "-i", "${var.cluster_name}"]
  }
}

# Alternative way to define kubernetes provider
#provider "kubernetes" {
#  host                   = "${var.cluster_endpoint}"
#  cluster_ca_certificate = "${var.cluster_ca_certificate}"
#  token                   = "${var.token}"
#  load_config_file       = false
#}

resource "kubernetes_config_map" "config_map_aws_auth" {
  metadata {
    name = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = <<YAML
- rolearn: ${var.aws_iam_role}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
YAML
  }

  depends_on = ["local_file.kubeconfig"]
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "${var.namespace}"
    labels {
      name = "${var.cluster_name}"
    }
  }
  depends_on = ["kubernetes_config_map.config_map_aws_auth"]
}

resource "kubernetes_service" "elasticsearch" {
  metadata {
    name = "elasticsearch"
    namespace = "${var.namespace}"
  }
  spec {
    type = "ExternalName"
    external_name = "${var.domain_endpoint}"
  }

  depends_on = ["kubernetes_namespace.namespace"]
}

resource "kubernetes_service_account" "tiller_account" {
  metadata {
    name = "${var.service_account}"
    namespace = "kube-system"
  }

  depends_on = ["kubernetes_config_map.config_map_aws_auth"]
}

resource "kubernetes_cluster_role_binding" "tiller_role_binding" {
  metadata {
    name = "${var.service_account}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "${var.service_account}"
    namespace = "kube-system"
  }

  depends_on = ["kubernetes_service_account.tiller_account"]
}

provider "helm" {
  install_tiller                  = true
  namespace                       = "kube-system"
  service_account                 = "${var.service_account}"
  tiller_image                    = "${var.tiller_image}"

  kubernetes {
    #host                   = "${var.cluster_endpoint}"
    #cluster_ca_certificate = "${var.cluster_ca_certificate}"
    #token                  = "${var.token}"
    config_path            = "${local_file.kubeconfig.filename}"
    load_config_file       = false
  }
}

data "helm_repository" "charts_stable" {
    name = "stable"
    url  = "https://github.com/helm/charts"
}

data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "efs-provisioner" {
  name       = "efs-provisioner"
  repository = "${data.helm_repository.charts_stable.metadata.0.name}"
  chart      = "efs-provisioner"

  set {
    name  = "efsProvisioner.efsFileSystemId"
    value = "${var.efs_id}"
  }

  set {
    name  = "efsProvisioner.awsRegion"
    value = "${var.region}"
  }

  depends_on = ["kubernetes_cluster_role_binding.tiller_role_binding"]
}

resource "helm_release" "my_redis_release" {
  name       = "my-redis-release"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart      = "redis"
  version    = "6.0.1"

  values = [
    "${file("values.yaml")}"
  ]

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set_string {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
  }
  
  depends_on = ["kubernetes_cluster_role_binding.tiller_role_binding"]
}
