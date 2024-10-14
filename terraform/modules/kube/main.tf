
provider "kubernetes" {
  host                   = var.kubernetes_endpoint
  cluster_ca_certificate = base64decode(var.kubernetes_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "eks"]
    command     = "aws"
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