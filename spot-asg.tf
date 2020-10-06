provider "spotinst" {
  account = var.spotinst_account
  token   = var.spotinst_token
}
provider "aws" {
  region = "us-east-1" // Change to your prefered region
}
locals {
  environment = "dev" // Change to your environment
  tags = {
    "Environment" = local.environment
    "Application" = "example-app-${local.environment}" // Change to your app name
  }
}
data "aws_ssm_parameter" "aws_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}
resource "aws_ecs_cluster" "application" {
  name = var.cluster_name

  tags = merge(
    var.tags,
    {
      "Name" = var.cluster_name
    },
  )
}
data "aws_region" "current" {}

data "template_file" "ecs_user_data" {
  template = file("${path.module}/data/ecs-user-data.tpl")

  vars = {
    ecs_cluster        = aws_ecs_cluster.application.name
    region             = data.aws_region.current.name
    efs_security_group = var.efs_security_group
  }
}
resource "aws_security_group" "ecs_app" {
  name        = "${local.environment}-app-ecs"
  description = "Allow app hosts to communicate"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
  }

  tags = merge(
    local.tags,
    map(
      "Name", "${local.environment}-app-ecs"
    )
  )
}
data "aws_availability_zones" "available" {}

locals {
  vpc_cidr = "10.50.0.0/16"
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.33.0"

  name = "${local.environment}-vpc"
  cidr = local.vpc_cidr

  enable_s3_endpoint = true

  azs = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[1],
    data.aws_availability_zones.available.names[2],
  ]

  private_subnets = [
    cidrsubnet(local.vpc_cidr, 7, 0),
    cidrsubnet(local.vpc_cidr, 7, 1),
    cidrsubnet(local.vpc_cidr, 7, 2),
  ]

  public_subnets = [
    cidrsubnet(local.vpc_cidr, 7, 50),
    cidrsubnet(local.vpc_cidr, 7, 51),
    cidrsubnet(local.vpc_cidr, 7, 52),
  ]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  public_subnet_tags = {
    "subnet_type" = "public"
  }

  private_subnet_tags = {
    "subnet_type" = "private"
  }
}
resource "spotinst_ocean_ecs" "ocean-autoscaling-group" {
  depends_on   = [module.vpc]
  region       = data.aws_region.current.name
  name         = var.cluster_name
  cluster_name = var.cluster_name

  min_size = 0

  subnet_ids = var.instance_subnets

  security_group_ids   = var.security_groups
  image_id             = data.aws_ssm_parameter.aws_ecs_ami.value
  iam_instance_profile = aws_iam_instance_profile.ecs-instance-profile.id

  key_pair  = var.instance_ssh_key
  user_data = data.template_file.ecs_user_data.rendered

  update_policy {
    should_roll = true

    roll_config {
      batch_size_percentage = 100
    }
  }

  tags {
    key   = "Name"
    value = "${aws_ecs_cluster.application.name}-worker"
  }

  tags {
    key   = "Environment"
    value = var.environment
  }

  tags {
    key   = "Application"
    value = "app-${var.environment}"
  }

  tags {
    key   = "Monitoring"
    value = "On"
  }
}
