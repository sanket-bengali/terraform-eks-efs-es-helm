### Terraform Kubernetes provider can be defined with any of the below 3 ways :

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

### Terraform Helm provider can be defined with any of the below 2 ways :

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
