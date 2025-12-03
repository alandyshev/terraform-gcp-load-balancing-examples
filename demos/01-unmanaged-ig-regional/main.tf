module "vpc" {
  source = "../../modules/vpc"

  vpc_name = local.vpc_name
}

module "regional_network" {
  source = "../../modules/regional_network"

  vpc_id   = module.vpc.vpc_id
  vpc_name = local.vpc_name
  region   = var.region

  backend_subnet_cidr           = local.backend_subnet_cidr
  frontend_subnet_cidr          = local.frontend_subnet_cidr
  external_lb_proxy_subnet_cidr = local.external_lb_proxy_subnet_cidr

  backend_port  = local.backend_port
  frontend_port = local.frontend_port

  depends_on = [module.vpc]
}

module "backend_service" {
  source = "../../modules/vm_unmanaged_group"

  service_name   = "backend"
  instance_names = ["backend-1", "backend-2"]

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.regional_network.backend_subnet_id
  zone      = var.zone

  machine_type = local.machine_type
  vm_image     = local.vm_image
  app_filename = "backend.py"

  port            = local.backend_port
  named_port_name = "backend-http"

  repo_url   = local.repo_url
  app_subdir = local.app_subdir

  depends_on = [module.regional_network]
}

module "frontend_service" {
  source = "../../modules/vm_unmanaged_group"

  service_name   = "frontend"
  instance_names = ["frontend-1", "frontend-2"]

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.regional_network.frontend_subnet_id
  zone      = var.zone

  machine_type = local.machine_type
  vm_image     = local.vm_image
  app_filename = "frontend.py"

  port            = local.frontend_port
  named_port_name = "http"

  repo_url   = local.repo_url
  app_subdir = local.app_subdir

  # Frontend calls backend via the internal load balancer
  backend_url = "http://${local.internal_lb_ip}:${local.backend_port}/info"

  depends_on = [module.regional_network]
}

# Internal L4 LB for backend
module "internal_lb" {
  source = "../../modules/internal_lb"

  region = var.region
  vpc_id = module.vpc.vpc_id

  subnet_id              = module.regional_network.backend_subnet_id
  backend_instance_group = module.backend_service.instance_group_self_link

  internal_lb_ip = local.internal_lb_ip
  port           = local.backend_port

  depends_on = [module.backend_service]
}

# External L7 LB for frontend
module "external_lb" {
  source = "../../modules/external_lb"

  region = var.region
  vpc_id = module.vpc.vpc_id

  external_lb_proxy_subnet_cidr = local.external_lb_proxy_subnet_cidr
  port                          = local.frontend_port

  frontend_instance_group = module.frontend_service.instance_group_self_link

  depends_on = [module.frontend_service]
}

# Debug firewall rules (SSH + ICMP). For demo only.
module "debug_firewall" {
  source = "../../modules/debug_firewall"

  vpc_id   = module.vpc.vpc_id
  vpc_name = local.vpc_name

  # For now we use defaults (0.0.0.0/0) for demo.
  # In more realistic setups, you could restrict these:
  # ssh_source_ranges  = ["203.0.113.0/24"]
  # icmp_source_ranges = ["203.0.113.0/24"]

  depends_on = [module.vpc]
}
