variable "project" {
  type        = string
  description = "GCP project ID where the demo resources will be deployed."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Default region for the demo."
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "Default zone for the demo."
}
