variable "project" {
  type        = string
  description = "GCP project ID where the demo resources will be deployed."
}

# -------- Region A / Region B configuration --------

variable "region_a" {
  type        = string
  default     = "us-central1"
  description = "First region for the global demo."
}

variable "zone_a" {
  type        = string
  default     = "us-central1-a"
  description = "Zone in the first region."
}

variable "region_b" {
  type        = string
  default     = "europe-west1"
  description = "Second region for the global demo."
}

variable "zone_b" {
  type        = string
  default     = "europe-west1-b"
  description = "Zone in the second region."
}

variable "region_a_suffix" {
  type        = string
  default     = "us"
  description = "Suffix for naming resources in region A (used in service_name, etc.)."
}

variable "region_b_suffix" {
  type        = string
  default     = "eu"
  description = "Suffix for naming resources in region B."
}