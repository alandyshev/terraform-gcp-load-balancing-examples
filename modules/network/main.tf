variable "vpc_name" {
  type = string
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
  type = string
}

variable "backend_port" {
  description = "Port used by backend service instances"
  type        = number
}

variable "frontend_port" {
  description = "Port used by frontend service instances"
  type        = number
}

locals {
  // Google load balancer / health check ranges
  // Ref: https://cloud.google.com/load-balancing/docs/firewall-rules
  health_check_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "backend" {
  name          = "${var.vpc_name}-sub-backend"
  ip_cidr_range = var.backend_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "frontend" {
  name          = "${var.vpc_name}-sub-frontend"
  ip_cidr_range = var.frontend_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

// The NAT resource lets VMs with no public IP access Internet
// The NAT resource requires a router to be created in the VPC.
resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.vpc_name}-nat"
  region = var.region
  router = google_compute_router.nat_router.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

// Backend app port – frontend subnet + health checks → backend instances
resource "google_compute_firewall" "backend_app" {
  name    = "${var.vpc_name}-backend-allow-app"
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  source_ranges = concat(
    [var.frontend_subnet_cidr],
    local.health_check_ranges,
  )

  target_tags = ["backend"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.backend_port)]
  }
}

// Frontend app port – only from external HTTP(S) LB proxies → frontend instances
resource "google_compute_firewall" "frontend_app" {
  name    = "${var.vpc_name}-frontend-allow-app"
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  source_ranges = distinct(
    concat(
      [var.external_lb_proxy_subnet_cidr],
      local.health_check_ranges,
    )
  )

  target_tags = ["frontend"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.frontend_port)]
  }
}

output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "backend_subnet_id" {
  value = google_compute_subnetwork.backend.id
}

output "frontend_subnet_id" {
  value = google_compute_subnetwork.frontend.id
}
