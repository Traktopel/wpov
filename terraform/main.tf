provider "aws" {
    region = var.region
}

#module "awsconfig" {
#    source = "./modules/awsconfig"
#}

#module "securityhub" {
#    source = "./modules/securityhub"
#}

#module "database" {
#    source = "./modules/database"
#}

module "network" {
    source = "./modules/network"
}

output "arn" {
    value = module.network.endpoint
}