variable "frontend_instance_groups" {
  description = "List of frontend instance group self_links (from multiple regions)"
  type        = list(string)
}

variable "port" {
  description = "Named port on the instance groups (e.g., 5500 on 'http')"
  type        = number
}

# Global external IP for the load balancer
resource "google_compute_global_address" "global_lb_ip" {
  name = "gcp-lb-demo-global-l7-ip"
}

# Global HTTP health check for frontend services
resource "google_compute_health_check" "frontend" {
  name = "gcp-lb-demo-global-hc-frontend"

  http_health_check {
    port         = var.port
    request_path = "/health"
  }
}

# Global backend service using multiple regional/zonal instance groups
resource "google_compute_backend_service" "frontend" {
  name                  = "gcp-lb-demo-global-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10

  health_checks = [google_compute_health_check.frontend.self_link]

  # Use the named port "http" defined on the instance groups (port = var.port)
  port_name = "http"

  dynamic "backend" {
    for_each = var.frontend_instance_groups
    content {
      group          = backend.value
      balancing_mode = "UTILIZATION"
    }
  }
}

resource "google_compute_url_map" "global" {
  name            = "gcp-lb-demo-global-url-map"
  default_service = google_compute_backend_service.frontend.self_link
}

resource "google_compute_target_http_proxy" "global" {
  name    = "gcp-lb-demo-global-http-proxy"
  url_map = google_compute_url_map.global.self_link
}

resource "google_compute_global_forwarding_rule" "global" {
  name        = "gcp-lb-demo-global-forwarding-rule"
  ip_address  = google_compute_global_address.global_lb_ip.address
  ip_protocol = "TCP"
  port_range  = "80"

  target = google_compute_target_http_proxy.global.self_link
}

output "global_lb_ip" {
  description = "Global external HTTP load balancer IP address"
  value       = google_compute_global_address.global_lb_ip.address
}