variable "service_name" {
  description = "Logical name of the service (used in IG name and instance tags, e.g. backend/frontend)"
  type        = string
}

variable "instance_names" {
  description = "List of instance names to create"
  type        = list(string)
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
  type = string
}

variable "machine_type" {
  type = string
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
  description = "Name of the named port (e.g. backend-http / frontend-http)"
  type        = string
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

// Optional backend URL (used only by frontend VMs)
variable "backend_url" {
  description = "Backend URL for the frontend service (BACKEND_URL env). Leave empty for backend."
  type        = string
  default     = ""
}

locals {
  instance_set = toset(var.instance_names)
}

resource "google_compute_instance" "vm" {
  for_each = local.instance_set

  name         = each.value
  machine_type = var.machine_type
  zone         = var.zone

  // Tag instances by service_name so firewall rules can target ["backend"] / ["frontend"]
  tags = [var.service_name]

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
  }

  boot_disk {
    initialize_params {
      image = var.vm_image
    }
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

resource "google_compute_instance_group" "group" {
  name    = "gcp-lb-demo-ig-${var.service_name}"
  zone    = var.zone
  network = var.vpc_id

  instances = [
    for inst in google_compute_instance.vm : inst.self_link
  ]

  named_port {
    name = var.named_port_name
    port = var.port
  }
}

output "instance_group_self_link" {
  value = google_compute_instance_group.group.self_link
}
