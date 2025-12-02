variable "vpc_id" {
  description = "VPC ID (self link) where debug firewall rules will be created"
  type        = string
}

variable "vpc_name" {
  description = "VPC name used as a prefix for firewall rule names"
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to access SSH (port 22). Default is 0.0.0.0/0 for demo purposes."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "icmp_source_ranges" {
  description = "CIDR ranges allowed to send ICMP (ping). Default is 0.0.0.0/0 for demo purposes."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  network = var.vpc_id

  direction = "INGRESS"
  priority  = 65534

  source_ranges = var.ssh_source_ranges

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "icmp" {
  name    = "${var.vpc_name}-allow-icmp"
  network = var.vpc_id

  direction = "INGRESS"
  priority  = 65534

  source_ranges = var.icmp_source_ranges

  allow {
    protocol = "icmp"
  }
}
