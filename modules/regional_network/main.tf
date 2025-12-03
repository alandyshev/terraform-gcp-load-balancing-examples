variable "vpc_id" {
  description = "ID (self link) of the VPC where regional resources will be created"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC (used as a prefix for regional resource names)"
  type        = string
}

variable "region" {
  type = string
}

variable "backend_subnet_cidr" {
  type = string
}

variable "frontend_subnet_cidr" {
  type = string
}

variable "external_lb_proxy_subnet_cidr" {
  description = "CIDR block used by the external LB proxy-only subnet (or 0.0.0.0/0 in Scenario 3)"
  type        = string
}

variable "backend_port" {
  description = "Port used by backend service instances"
  type        = number
}

variable "frontend_port" {
  description = "Port used by frontend service instances"
  type        = number
}

variable "name_suffix" {
  description = "Short suffix to distinguish regional resources (e.g. us / eu). Empty for single-region scenarios."
  type        = string
  default     = ""
}

locals {
  // Google load balancer / health check ranges
  // Ref: https://cloud.google.com/load-balancing/docs/firewall-rules
  health_check_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  // Region-specific tags, but keep plain names when suffix is empty
  backend_tag  = var.name_suffix == "" ? "backend" : "backend-${var.name_suffix}"
  frontend_tag = var.name_suffix == "" ? "frontend" : "frontend-${var.name_suffix}"
}

resource "google_compute_subnetwork" "backend" {
  name          = "${var.vpc_name}-${var.name_suffix}-sub-backend"
  ip_cidr_range = var.backend_subnet_cidr
  region        = var.region
  network       = var.vpc_id
}

resource "google_compute_subnetwork" "frontend" {
  name          = "${var.vpc_name}-${var.name_suffix}-sub-frontend"
  ip_cidr_range = var.frontend_subnet_cidr
  region        = var.region
  network       = var.vpc_id
}

resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-${var.name_suffix}-router"
  region  = var.region
  network = var.vpc_id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.vpc_name}-${var.name_suffix}-nat"
  region = var.region
  router = google_compute_router.nat_router.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

// Backend app port – frontend subnet + health checks → backend instances (region-scoped)
resource "google_compute_firewall" "backend_app" {
  name    = "${var.vpc_name}-${var.name_suffix}-backend-allow-app"
  network = var.vpc_id

  direction = "INGRESS"
  priority  = 1000

  source_ranges = concat(
    [var.frontend_subnet_cidr],
    local.health_check_ranges,
  )

  # Region-specific backend tag, or plain "backend" if no suffix
  target_tags = [local.backend_tag]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.backend_port)]
  }
}

// Frontend app port – from external L7 LB / internet + health checks → frontend instances (region-scoped)
resource "google_compute_firewall" "frontend_app" {
  name    = "${var.vpc_name}-${var.name_suffix}-frontend-allow-app"
  network = var.vpc_id

  direction = "INGRESS"
  priority  = 1000

  source_ranges = distinct(
    concat(
      [var.external_lb_proxy_subnet_cidr],
      local.health_check_ranges,
    )
  )

  # Region-specific frontend tag, or plain "frontend" if no suffix
  target_tags = [local.frontend_tag]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.frontend_port)]
  }
}

output "backend_subnet_id" {
  value = google_compute_subnetwork.backend.id
}

output "frontend_subnet_id" {
  value = google_compute_subnetwork.frontend.id
}