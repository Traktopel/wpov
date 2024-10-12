provider "aws" {
    region = var.region
}

#module "awsconfig" {
#    source = "./modules/awsconfig"
#}

#module "securityhub" {
#    source = "./modules/securityhub"
#}

module "database" {
    source = "./modules/database"
}