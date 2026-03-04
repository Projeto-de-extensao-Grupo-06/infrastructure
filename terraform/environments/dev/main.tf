terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../modules/vpc"

  environment     = "dev"
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
}

module "ec2_dev" {
  source = "../../modules/ec2"

  environment   = "dev"
  instance_name = "dev-machine"
  instance_type = "t3.medium"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
}

module "s3_raw" {
  source = "../../modules/s3"

  environment = "dev"
  bucket_name = "solarize-datalake-raw"
}

module "s3_trusted" {
  source = "../../modules/s3"

  environment = "dev"
  bucket_name = "solarize-datalake-trusted"
}

module "s3_refined" {
  source = "../../modules/s3"

  environment = "dev"
  bucket_name = "solarize-datalake-refined"
}
