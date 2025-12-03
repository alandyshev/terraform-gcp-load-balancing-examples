variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

output "vpc_id" {
  description = "Self link (ID) of the created VPC"
  value       = google_compute_network.vpc.id
}