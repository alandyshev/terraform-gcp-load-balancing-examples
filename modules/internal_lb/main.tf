variable "region" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID (self link) where the internal load balancer lives"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID (self link) in which the ILB IP is allocated (backend subnet)"
  type        = string
}

variable "backend_instance_group" {
  description = "Self link of the backend instance group"
  type        = string
}

variable "internal_lb_ip" {
  description = "Internal IP address for the ILB (must be inside backend subnet CIDR)"
  type        = string
}

variable "port" {
  description = "Port that backend app listens on"
  type        = number
}

resource "google_compute_region_health_check" "backend" {
  name   = "gcp-lb-demo-hc-backend"
  region = var.region

  tcp_health_check {
    port = var.port
  }
}

resource "google_compute_region_backend_service" "backend" {
  name                  = "gcp-lb-demo-internal-lb-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"

  health_checks = [
    google_compute_region_health_check.backend.self_link
  ]

  backend {
    group          = var.backend_instance_group
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_address" "internal_lb" {
  name         = "gcp-lb-demo-ip-internal-lb"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnet_id
  address      = var.internal_lb_ip
}

resource "google_compute_forwarding_rule" "internal_lb_frontend" {
  name                  = "gcp-lb-demo-internal-lb-forwarding-rule"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "TCP"

  // The port clients use to reach the backend service
  ports = [tostring(var.port)]

  // ILB IP lives in the backend subnet
  network    = var.vpc_id
  subnetwork = var.subnet_id
  ip_address = google_compute_address.internal_lb.address

  backend_service = google_compute_region_backend_service.backend.id
}

output "internal_lb_ip" {
  description = "Internal ILB IP address"
  value       = google_compute_address.internal_lb.address
}
