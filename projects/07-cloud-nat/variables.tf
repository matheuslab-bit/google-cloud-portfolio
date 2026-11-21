variable "project_id" {
  description = "Google Cloud project ID where the Cloud NAT gateway is created."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID (6 to 30 lowercase letters, digits, or hyphens)."
  }
}

variable "region" {
  description = "Region of the subnet that gets outbound access (Cloud Router and NAT are regional)."
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "VPC created by Lab 01."
  type        = string
  default     = "portfolio-vpc"
}

variable "subnet_name" {
  description = "The only subnet allowed to use the NAT gateway (the Lab 02 subnet)."
  type        = string
  default     = "lab02-iowa-subnet"
}
