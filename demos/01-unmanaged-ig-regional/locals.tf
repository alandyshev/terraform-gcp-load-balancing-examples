locals {
  # VPC name for this demo
  vpc_name = "gcp-lb-demo-vpc"

  # Subnet CIDRs
  backend_subnet_cidr           = "172.16.0.0/24"
  frontend_subnet_cidr          = "172.16.1.0/24"
  external_lb_proxy_subnet_cidr = "172.16.2.0/24" # proxy-only subnet for external L7 LB

  # Compute / image (single image used for all VMs)
  vm_image     = "debian-cloud/debian-12"
  machine_type = "e2-micro"

  # App ports
  backend_port  = 5501
  frontend_port = 5500

  # Internal Load Balancer IP (must be inside backend_subnet_cidr)
  internal_lb_ip = "172.16.0.200"

  # App repository and relative path to the test app
  repo_url   = "https://github.com/alandyshev/terraform-gcp-load-balancing-examples.git"
  app_subdir = "test-app"
}
