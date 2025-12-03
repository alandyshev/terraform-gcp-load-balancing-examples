locals {
  # VPC name for this demo
  vpc_name = "gcp-lb-demo-vpc-global"

  # App ports
  backend_port  = 5501
  frontend_port = 5500

  # Compute / image (single image used for all VMs)
  vm_image     = "debian-cloud/debian-12"
  machine_type = "e2-micro"

  # App repository and relative path to the test app
  repo_url   = "https://github.com/alandyshev/terraform-gcp-load-balancing-examples.git"
  app_subdir = "test-app"

  # Region A configuration
  region_a = {
    suffix               = var.region_a_suffix
    region               = var.region_a
    zone                 = var.zone_a
    backend_subnet_cidr  = "10.10.0.0/24"
    frontend_subnet_cidr = "10.10.1.0/24"
    # For the global L7 LB we treat the frontend as publicly reachable.
    # regional_network uses this for frontend firewall rules.
    external_lb_proxy_subnet_cidr = "0.0.0.0/0"
    internal_lb_ip                = "10.10.0.200"
  }

  # Region B configuration
  region_b = {
    suffix                        = var.region_b_suffix
    region                        = var.region_b
    zone                          = var.zone_b
    backend_subnet_cidr           = "10.20.0.0/24"
    frontend_subnet_cidr          = "10.20.1.0/24"
    external_lb_proxy_subnet_cidr = "0.0.0.0/0"
    internal_lb_ip                = "10.20.0.200"
  }
}
