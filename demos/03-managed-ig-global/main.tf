# Global VPC
module "vpc" {
  source   = "../../modules/vpc"
  vpc_name = local.vpc_name
}

# Regional networking (Region A)
module "regional_network_a" {
  source = "../../modules/regional_network"

  vpc_id   = module.vpc.vpc_id
  vpc_name = local.vpc_name
  region   = local.region_a.region

  backend_subnet_cidr  = local.region_a.backend_subnet_cidr
  frontend_subnet_cidr = local.region_a.frontend_subnet_cidr

  backend_port  = local.backend_port
  frontend_port = local.frontend_port

  name_suffix = local.region_a.suffix
}

# Regional networking (Region B)
module "regional_network_b" {
  source = "../../modules/regional_network"

  vpc_id   = module.vpc.vpc_id
  vpc_name = local.vpc_name
  region   = local.region_b.region

  backend_subnet_cidr  = local.region_b.backend_subnet_cidr
  frontend_subnet_cidr = local.region_b.frontend_subnet_cidr

  backend_port  = local.backend_port
  frontend_port = local.frontend_port

  name_suffix = local.region_b.suffix
}

# Regional service stack (Region A)
module "region_a_stack" {
  source = "../../modules/regional_service_stack"

  region        = local.region_a.region
  zone          = local.region_a.zone
  region_suffix = local.region_a.suffix

  vpc_id             = module.vpc.vpc_id
  backend_subnet_id  = module.regional_network_a.backend_subnet_id
  frontend_subnet_id = module.regional_network_a.frontend_subnet_id

  internal_lb_ip = local.region_a.internal_lb_ip

  machine_type  = local.machine_type
  vm_image      = local.vm_image
  backend_port  = local.backend_port
  frontend_port = local.frontend_port
  repo_url      = local.repo_url
  app_subdir    = local.app_subdir

  autoscaling_min_replicas = 2
  autoscaling_max_replicas = 10
}

# Regional service stack (Region B)
module "region_b_stack" {
  source = "../../modules/regional_service_stack"

  region        = local.region_b.region
  zone          = local.region_b.zone
  region_suffix = local.region_b.suffix

  vpc_id             = module.vpc.vpc_id
  backend_subnet_id  = module.regional_network_b.backend_subnet_id
  frontend_subnet_id = module.regional_network_b.frontend_subnet_id

  internal_lb_ip = local.region_b.internal_lb_ip

  machine_type  = local.machine_type
  vm_image      = local.vm_image
  backend_port  = local.backend_port
  frontend_port = local.frontend_port
  repo_url      = local.repo_url
  app_subdir    = local.app_subdir

  autoscaling_min_replicas = 2
  autoscaling_max_replicas = 10
}

# Global L7 load balancer (HTTP)
module "global_lb" {
  source = "../../modules/global_external_lb"

  frontend_instance_groups = [
    module.region_a_stack.frontend_instance_group_self_link,
    module.region_b_stack.frontend_instance_group_self_link,
  ]

  port = local.frontend_port
}

# Debug firewall rules (SSH + ICMP). For demo only – do NOT use these defaults in production.
module "debug_firewall" {
  source = "../../modules/debug_firewall"

  vpc_id   = module.vpc.vpc_id
  vpc_name = local.vpc_name
}