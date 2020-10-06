module "ecs-cluster-spot" {
  source           = "github.com/juliamulko/terraform-aws-ecs-spotio?ref=initial-implementation"
  cluster_name     = "${local.environment}-ecs"
  environment      = local.environment
  tags             = local.tags
  instance_subnets = module.vpc.private_subnets
  instance_ssh_key = "${local.environment}-app-key" // Your instance key name here
  security_groups  = "${concat(list("${aws_security_group.ecs_app.id}"), "${var.app_cluster_extra_sg}")}"
  spotinst_account = var.spotinst_account
  spotinst_token   = var.spotinst_token
}
