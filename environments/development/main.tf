provider "aws" {
  region = "us-west-2"
}

data aws_region current {}

resource "aws_s3_bucket" "test" {
  bucket_prefix = "jks-tf-${var.environment}"
  tags = {
    Name        = "Test bucket"
    Environment = var.environment
    Terraform   = "true"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name = "jks-mutiple-tf-environments-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.2.1"

  repository_name = "profilesvc-${var.environment}"

  repository_read_write_access_arns = ["arn:aws:iam::461768693077:role/terraform"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

output "ecr_repo_url" {
  value = module.ecr.repository_url
}
output "ecr_registry_id" {
  value = module.ecr.repository_registry_id
}

module "tf-docker" {
  source = "../../modules/tf-docker"

  environment         = var.environment
  aws_region          = data.aws_region.current.name 
  ecr_reg_id          = module.ecr.repository_registry_id
  ecr_repo_url        = module.ecr.repository_url
  image_tag           = "latest"
  force_image_rebuild = false
}

module "ecs" {
  source = "../../modules/ecs"

  environment = var.environment
  aws_region  = data.aws_region.current.name

  alb_port = 80
  app_port = 8080

  ecr_repo_url = module.ecr.repository_url
  image_tag    = "latest"

  vpc_id = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets

  app_image = "${module.ecr.repository_url}:latest"
}

output "alb_hostname" {
  value = module.ecs.alb_hostname
}