variable "cluster_endpoint" {
  type = "string"
}

variable "cluster_ca_certificate" {
  type = "string"
}

variable "kubeconfig_filename" {
  type = "string"
}

variable "kubeconfig" {
  type = "string"
}

variable "namespace" {
  type = "string"
}

variable "domain_endpoint" {
  type = "string"
}

variable "cluster_name" {
  type = "string"
}

variable "aws_iam_role" {
  type = "string"
}

variable "service_account" {
  default = "tiller"
}

variable "tiller_image" {
  default = "gcr.io/kubernetes-helm/tiller:v2.13.1"
}

variable "efs_id" {
  type = "string"
}

variable "region" {
  type = "string"
}

