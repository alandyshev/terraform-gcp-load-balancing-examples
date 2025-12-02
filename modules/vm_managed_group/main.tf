variable "service_name" {
  description = "Logical name of the service (used in MIG name, instance base name, and tags, e.g. backend/frontend)"
  type        = string
}

variable "vpc_id" {
  description = "ID (self link) of the VPC where instances will be created"
  type        = string
}

variable "subnet_id" {
  description = "ID (self link) of the subnet where instances will be created"
  type        = string
}

variable "zone" {
  description = "Zone in which the managed instance group will be created"
  type        = string
}

variable "machine_type" {
  description = "Machine type for instances (e.g. e2-micro)"
  type        = string
}

variable "vm_image" {
  description = "VM image used to boot instances (e.g., debian-cloud/debian-12)"
  type        = string
}

variable "app_filename" {
  description = "Python file to run (backend.py / frontend.py)"
  type        = string
}

variable "port" {
  description = "Port that the app listens on"
  type        = number
}

variable "named_port_name" {
  description = "Name of the named port (e.g. backend-http / http)"
  type        = string
}

// Autoscaling configuration
variable "autoscaling_enabled" {
  description = "Enable CPU-based autoscaling for the managed instance group"
  type        = bool
  default     = true
}

variable "autoscaling_min_replicas" {
  description = "Minimum number of instances in the managed instance group"
  type        = number
  default     = 2
}

variable "autoscaling_max_replicas" {
  description = "Maximum number of instances in the managed instance group"
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target average CPU utilization (0.0–1.0) for autoscaling"
  type        = number
  default     = 0.8
}

// Git repo + app folder inside the repo
variable "repo_url" {
  description = "Git repository URL with the test app"
  type        = string
}

variable "app_subdir" {
  description = "Subdirectory inside the repo that contains the Flask app"
  type        = string
  default     = "test-app"
}

// Optional backend URL (used only by frontend service)
variable "backend_url" {
  description = "Backend URL for the frontend service (BACKEND_URL env). Leave empty for backend."
  type        = string
  default     = ""
}

// Health check for MIG autohealing (separate from LB health checks)
resource "google_compute_health_check" "mig" {
  name = "gcp-lb-demo-hc-mig-${var.service_name}"

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 1
  unhealthy_threshold = 6

  http_health_check {
    port         = var.port
    request_path = "/health"
  }
}

resource "google_compute_instance_template" "this" {
  name_prefix  = "gcp-lb-demo-mig-${var.service_name}-"
  machine_type = var.machine_type

  // Tag instances by service_name so firewall rules can target ["backend"] / ["frontend"]
  tags = [var.service_name]

  disk {
    boot         = true
    auto_delete  = true
    source_image = var.vm_image
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
    // No external IPs; outbound goes via Cloud NAT in the VPC.
  }

  metadata = {
    startup-script = templatefile(
      "${path.module}/startup.sh",
      {
        repo_url     = var.repo_url
        app_subdir   = var.app_subdir
        app_filename = var.app_filename
        port         = var.port
        backend_url  = var.backend_url
        service_name = var.service_name
      }
    )
  }
}

resource "google_compute_instance_group_manager" "this" {
  name               = "gcp-lb-demo-mig-${var.service_name}"
  base_instance_name = "gcp-lb-demo-mig-${var.service_name}"
  zone               = var.zone

  // Start with the minimum replica count for this group.
  target_size = var.autoscaling_min_replicas

  version {
    name              = "primary"
    instance_template = google_compute_instance_template.this.self_link
  }

  named_port {
    name = var.named_port_name
    port = var.port
  }

  // Autohealing: recreate instances that fail this health check
  auto_healing_policies {
    health_check      = google_compute_health_check.mig.self_link
    initial_delay_sec = 240
  }
}

// CPU-based autoscaler (optional, controlled by autoscaling_enabled)
resource "google_compute_autoscaler" "this" {
  count = var.autoscaling_enabled ? 1 : 0

  name   = "gcp-lb-demo-as-${var.service_name}"
  zone   = var.zone
  target = google_compute_instance_group_manager.this.self_link

  autoscaling_policy {
    min_replicas    = var.autoscaling_min_replicas
    max_replicas    = var.autoscaling_max_replicas
    cooldown_period = 300

    cpu_utilization {
      target = var.autoscaling_cpu_target
    }
  }
}

output "instance_group_self_link" {
  description = "Self link of the underlying managed instance group (used by load balancers)"
  value       = google_compute_instance_group_manager.this.instance_group
}