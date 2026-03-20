module "vpc" {
  source = "../../modules/vpc"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
}

module "ec2_qa" {
  source = "../../modules/ec2"

  environment   = var.environment
  instance_name = "qa-machine"
  instance_type = var.instance_type
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  
  frontend_ports = [22, 80, 443, 8000, 8080, 8081, 8082, 5678, 3000, 3306, 3307]
  user_data      = file("../../../scripts/setup-qa.sh")
}

module "s3_bronze" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_bronze_name
}

module "s3_silver" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_silver_name
}

module "s3_gold" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_gold_name
}
