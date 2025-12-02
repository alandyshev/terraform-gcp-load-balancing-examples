variable "region" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID (self link) where the external LB proxy-only subnet is created"
  type        = string
}

variable "external_lb_proxy_subnet_cidr" {
  description = "CIDR block for the external LB proxy-only subnet (REGIONAL_MANAGED_PROXY)"
  type        = string
}

variable "port" {
  description = "Port that frontend app listens on"
  type        = number
}

variable "frontend_instance_group" {
  description = "Self link of the frontend instance group"
  type        = string
}

// Subnet for external managed HTTP(S) LB proxies
resource "google_compute_subnetwork" "external_lb_proxy" {
  name          = "gcp-lb-demo-sub-external-lb-proxy"
  ip_cidr_range = var.external_lb_proxy_subnet_cidr
  region        = var.region
  network       = var.vpc_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

// External IP for external managed LB
resource "google_compute_address" "external_lb" {
  name   = "gcp-lb-demo-ip-external-lb"
  region = var.region
}

resource "google_compute_region_health_check" "frontend" {
  name   = "gcp-lb-demo-hc-frontend"
  region = var.region

  http_health_check {
    port         = var.port
    request_path = "/health"
  }
}

resource "google_compute_region_backend_service" "frontend" {
  name                  = "gcp-lb-demo-external-lb-backend"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 10

  health_checks = [
    google_compute_region_health_check.frontend.self_link
  ]

  backend {
    group           = var.frontend_instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_url_map" "external_lb_url_map" {
  name   = "gcp-lb-demo-external-lb-url-map"
  region = var.region

  default_service = google_compute_region_backend_service.frontend.self_link

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_region_target_http_proxy" "external_lb_http_proxy" {
  name   = "gcp-lb-demo-external-lb-http-proxy"
  region = var.region

  url_map = google_compute_region_url_map.external_lb_url_map.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

resource "google_compute_forwarding_rule" "external_lb_frontend" {
  name                  = "gcp-lb-demo-external-lb-forwarding-rule"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"

  port_range = tostring(var.port)
  network    = var.vpc_id

  ip_address = google_compute_address.external_lb.address
  target     = google_compute_region_target_http_proxy.external_lb_http_proxy.id

  depends_on = [
    google_compute_subnetwork.external_lb_proxy
  ]
}

output "external_lb_ip" {
  description = "External load balancer IP address"
  value       = google_compute_address.external_lb.address
}
