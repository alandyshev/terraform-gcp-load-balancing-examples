# Regional stack for a single region:
#
# - Backend managed instance group
# - Frontend managed instance group
# - Internal L4 load balancer for the backend
#
# This module is used both for single-region demos and as the per-region
# building block in the global load balancing scenario.

variable "vpc_id" {
  description = "ID (self link) of the VPC where instances will be created"
  type        = string
}

variable "region" {
  description = "Region for this stack (e.g. europe-west1)"
  type        = string
}

variable "zone" {
  description = "Zone for this stack (e.g. europe-west1-b)"
  type        = string
}

variable "backend_subnet_id" {
  description = "Subnet ID (self link) for backend instances"
  type        = string
}

variable "frontend_subnet_id" {
  description = "Subnet ID (self link) for frontend instances"
  type        = string
}

variable "backend_port" {
  description = "Port that backend app listens on"
  type        = number
}

variable "frontend_port" {
  description = "Port that frontend app listens on"
  type        = number
}

variable "internal_lb_ip" {
  description = "Internal IP address for the regional internal load balancer (must be inside backend subnet CIDR)"
  type        = string
}

variable "vm_image" {
  description = "VM image used to boot instances (e.g., debian-cloud/debian-12)"
  type        = string
}

variable "machine_type" {
  description = "Machine type for instances (e.g., e2-micro)"
  type        = string
}

variable "repo_url" {
  description = "Git repository URL with the test app"
  type        = string
}

variable "app_subdir" {
  description = "Subdirectory inside the repo that contains the Flask app"
  type        = string
  default     = "test-app"
}

variable "region_suffix" {
  description = "Short suffix to distinguish this region (e.g. us / eu / a / b). May be empty for single-region use."
  type        = string
  default     = ""
}

variable "autoscaling_min_replicas" {
  description = "Min number of replicas for the MIGs"
  type        = number
  default     = 2
}

variable "autoscaling_max_replicas" {
  description = "Max number of replicas for the MIGs"
  type        = number
  default     = 10
}

locals {
  # Hardened service names:
  # - if region_suffix == "" → plain "backend" / "frontend"
  # - otherwise → "backend-<suffix>" / "frontend-<suffix>"
  backend_service_name  = var.region_suffix == "" ? "backend" : "backend-${var.region_suffix}"
  frontend_service_name = var.region_suffix == "" ? "frontend" : "frontend-${var.region_suffix}"
}

# Backend managed instance group (per region)
module "backend_service" {
  source = "../vm_managed_group"

  service_name = local.backend_service_name

  vpc_id    = var.vpc_id
  subnet_id = var.backend_subnet_id
  zone      = var.zone

  machine_type = var.machine_type
  vm_image     = var.vm_image
  app_filename = "backend.py"

  port            = var.backend_port
  named_port_name = "backend-http"

  repo_url   = var.repo_url
  app_subdir = var.app_subdir

  # Autoscaling settings propagated from this regional stack
  autoscaling_min_replicas = var.autoscaling_min_replicas
  autoscaling_max_replicas = var.autoscaling_max_replicas
}

# Internal L4 LB for backend (per region)
module "internal_lb" {
  source = "../internal_lb"

  region = var.region
  vpc_id = var.vpc_id

  subnet_id              = var.backend_subnet_id
  backend_instance_group = module.backend_service.instance_group_self_link

  internal_lb_ip = var.internal_lb_ip
  port           = var.backend_port
}

# Frontend managed instance group (per region)
module "frontend_service" {
  source = "../vm_managed_group"

  service_name = local.frontend_service_name

  vpc_id    = var.vpc_id
  subnet_id = var.frontend_subnet_id
  zone      = var.zone

  machine_type = var.machine_type
  vm_image     = var.vm_image
  app_filename = "frontend.py"

  port            = var.frontend_port
  named_port_name = "http"

  repo_url   = var.repo_url
  app_subdir = var.app_subdir

  # Frontend calls backend via the internal load balancer in this region
  backend_url = "http://${var.internal_lb_ip}:${var.backend_port}/info"

  autoscaling_min_replicas = var.autoscaling_min_replicas
  autoscaling_max_replicas = var.autoscaling_max_replicas
}

output "backend_instance_group_self_link" {
  description = "Self link of the regional backend instance group"
  value       = module.backend_service.instance_group_self_link
}

output "frontend_instance_group_self_link" {
  description = "Self link of the regional frontend instance group"
  value       = module.frontend_service.instance_group_self_link
}

output "backend_internal_lb_ip" {
  description = "Internal Load Balancer IP address for the backend in this region"
  value       = module.internal_lb.internal_lb_ip
}