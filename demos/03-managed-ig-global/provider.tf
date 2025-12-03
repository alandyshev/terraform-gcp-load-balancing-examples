terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.12"
    }
  }
}

// https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
provider "google" {
  project = var.project
  region  = var.region_a
  zone    = var.zone_a
}