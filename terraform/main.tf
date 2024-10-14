provider "aws" {
    region = var.region
}

module "awsconfig" {
    source = "./modules/awsconfig"
}

module "securityhub" {
    source = "./modules/securityhub"
}

module "database" {
    source = "./modules/database"
}

output "ip" {
  value = module.database.database_ip
}

module "eks" {
    source = "./modules/eks"
    database_ip = module.database.database_ip
}

