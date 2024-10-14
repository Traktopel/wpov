provider "aws" {
    region = var.region
}

module "awsconfig" {
    source = "./modules/awsconfig"
}

module "securityhub" {
    source = "./modules/securityhub"
}

module "eks" {
    source = "./modules/eks"
}


module "database" {
    source = "./modules/database"
    eks_node_role=module.eks.node_role
}


module "kube"{
    source = "./modules/kube"
    database_fqdn = module.database.database_ip
    kubernetes_endpoint=module.eks.eks_endpoint
    kubernetes_ca=module.eks.eks_ca
}