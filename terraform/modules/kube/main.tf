terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}
provider "helm" {
  kubernetes {
    host                   = var.kubernetes_endpoint
    cluster_ca_certificate = base64decode(var.kubernetes_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "eks"]
    }
  }
}

resource "helm_release" "flux" {
  name       = "flux"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
}


provider "kubectl" {
  apply_retry_count      = 15
  host                   = var.kubernetes_endpoint
  cluster_ca_certificate = base64decode(var.kubernetes_ca)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      "eks"
    ]
  }
}

resource "kubectl_manifest" "kaniko" {
  yaml_body =file("${path.module}/build.yaml")
  depends_on = [helm_release.flux]
}


resource "time_sleep" "wait_5_min" {
  depends_on = [helm_release.flux]

  create_duration = "5m"
}

resource "kubectl_manifest" "gitrepo" {
  yaml_body = file("${path.module}/gitrepo.yaml")
  depends_on = [time_sleep.wait_5_min]
}

resource "kubectl_manifest" "kustomization" {
  yaml_body = file("${path.module}/kustomization.yaml")
  depends_on = [time_sleep.wait_5_min]
}

resource "kubectl_manifest" "cluster-admin" {
  yaml_body = file("${path.module}/cluster-rolebinding.yaml")
  depends_on = [time_sleep.wait_5_min]
}

