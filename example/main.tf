provider "aws" {
  region = "us-east-1" // Change to your prefered region
}
provider "spotinst" {
  account = var.spotinst_account
  token   = var.spotinst_token
}

resource "spotinst_ocean_ecs" "ocean-autoscaling-group" {
  depends_on = [module.vpc]
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

locals {
  environment = "dev" // Change to your environment
  tags = {
    "Environment" = local.environment
    "Application" = "example-app-${local.environment}" // Change to your app name
  }
}

module "ecs-cluster-spot" {
  source           = "github.com/noamozer/terraform-aws-ecs-spotio?ref=initial-implementation"
  cluster_name     = "${local.environment}-ecs"
  environment      = local.environment
  tags             = local.tags
  instance_subnets = module.vpc.private_subnets
  instance_ssh_key = "${local.environment}-app-key" // Your instance key name here
  security_groups  = "${concat(list("${aws_security_group.ecs_app.id}"), "${var.app_cluster_extra_sg}")}"
  spotinst_account = var.spotinst_account
  spotinst_token   = var.spotinst_token
}
