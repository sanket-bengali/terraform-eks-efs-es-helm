### 1. EKS worker nodes bootstrap script

```
locals {
 worker-userdata = <<USERDATA
#!/bin/bash

set -o xtrace

/etc/eks/bootstrap.sh \
 — apiserver-endpoint ‘${var.cluster_endpoint}’ \
 — b64-cluster-ca ‘${var.cluster_certificate_authority_data}’ \
 ‘${var.cluster_name}’

USERDATA
}
```

### 2. Kubeconfig file generation steps :

### For that, below additional change to be done in the auto-scaling module (by Cloudposse) :

#### a. In the input.tf, add below additional variables :

```
variable "cluster_name" {
  type = "string"
}
variable "cluster_endpoint" {
  type = "string"
}
variable "cluster_certificate_authority_data" {
  type = "string"
}
variable "kubeconfig_aws_authenticator_command" {
  description = "Command to use to to fetch AWS EKS credentials."
  default     = "aws-iam-authenticator"
}
```

#### b. In the main.tf, add below code to generate kubeconfig file from kubeconfig.tpl file :

```
data "template_file" "kubeconfig" {
  count    = "${var.enabled == "true" ? 1 : 0}"
  template = "${file("${path.module}/kubeconfig.tpl")}"
vars {
    server                     = "${var.cluster_endpoint}"
    certificate_authority_data = "${var.cluster_certificate_authority_data}"
    cluster_name               = "${var.cluster_name}"
aws_authenticator_command         = "${var.kubeconfig_aws_authenticator_command}"
    aws_authenticator_command_args    = "${join("\n", formatlist("\"%s\"", list("token", "-i", module.label.id)))}"
  }
depends_on = ["aws_autoscaling_group.default"]
}
```

#### kubeconfig.tpl file :

```
apiVersion: v1
kind: Config
preferences: {}

clusters:
- cluster:
    server: ${server}
    certificate-authority-data: ${certificate_authority_data}
  name: ${cluster_name}

contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}
  name: ${cluster_name}

current-context: ${cluster_name}

users:
- name: ${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${cluster_name}"
```

#### c. In the output.tf, store rendered kubeconfig (from the template file) inside a variable :

output "kubeconfig" {
  value = "${join("", data.template_file.kubeconfig.*.rendered)}"
}

### 3. Terraform Kubernetes provider can be defined with any of the below 3 ways :

#### a. With required parameters like cluster_endpoint, ca_certificate along with aws-iam-authenticator token generation command :

```
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
```

#### b. With required parameters like cluster_endpoint, certificate_data and generated token by aws-iam-authenticator :

authenticator script :

```
#!/bin/bash
set -e

# Extract cluster name from STDIN
eval "$(jq -r '@sh "CLUSTER_NAME=\(.cluster_name)"')"

# Retrieve token with AWS IAM Authenticator
TOKEN=$(aws-iam-authenticator token -i $CLUSTER_NAME | jq -r .status.token)

# Output token as JSON
jq -n --arg token "$TOKEN" '{"token": $token}'
```

Execute the script with cluster_name as input (should be added inside eks-cluster/main.tf):

```
data "external" "aws_iam_authenticator" {
  program = ["bash", "${path.module}/authenticator.sh"]

query {
    cluster_name = "${module.label.id}"
  }
}
```

Mini version of this (without authenticator.sh script) :

```
data "external" "aws_iam_authenticator" {
  program = ["sh", "-c", "aws-iam-authenticator token -i ${var.cluster_name} | jq -r -c .status"]
}
```

Store the generated token as output variable, which can be used in the my-app module :

```
output "aws_authenticator_token" {
  value = "${data.external.aws_iam_authenticator.result["token"]}"
  description = "AWS EKS Authentication token"
}
```

And from my-app module, token variable can be passed to the my-app-eks-setup module to be used in the Kubernetes provider :

```
provider "kubernetes" {
  host                    = "${var.cluster_endpoint}"
  cluster_ca_certificate  = "${var.cluster_ca_certificate}"
  token                   = "${var.token}"
  load_config_file        = false
}
```

#### c. Using the kubeconfig file passed from my-app module, store as local file in the my-app-eks-setup module :

```
resource "local_file" "kubeconfig" {
  content  = "${var.kubeconfig}"
  filename = "${var.kubeconfig_filename}"
}

provider "kubernetes" {
  config_path            = "${local_file.kubeconfig.filename}"
  load_config_file       = false
}
```

### 4. Apply configmap for AWS auth for worker nodes :

```
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
```

### 5. Create service account for Tiller and application namespace (in parallel) :

```
resource "kubernetes_service_account" "tiller_account" {
  metadata {
    name = "${var.service_account}"
    namespace = "kube-system"
  }
depends_on = ["kubernetes_config_map.config_map_aws_auth"]
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
```

### 6. Bind "cluster-admin" ClusterRole with the service account

```
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
```

### 7. Apply service to register Elasticsearch domain endpoint :

```
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
```

### 8. Terraform Helm provider can be defined with any of the below 2 ways :

#### a. Using required parameters like cluster_endpoint, ca_certificate, token.

```
provider "helm" {
  install_tiller                  = true
  namespace                       = "kube-system"
  service_account                 = "${var.service_account}"
  tiller_image                    = "${var.tiller_image}"

kubernetes {
    host                   = "${var.cluster_endpoint}"
    cluster_ca_certificate = "${var.cluster_ca_certificate}"
    token                  = "${var.token}"
    load_config_file       = false
  }
}
```

#### b. Using the kubeconfig file :

```
provider "helm" {
  install_tiller                  = true
  namespace                       = "kube-system"
  service_account                 = "${var.service_account}"
  tiller_image                    = "${var.tiller_image}"

kubernetes {
    config_path            = "${local_file.kubeconfig.filename}"
    load_config_file       = false
  }
}
```
