variable "project_id" {
  description = "Google Cloud project ID that GitHub Actions is allowed to read."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID (6 to 30 lowercase letters, digits, or hyphens)."
  }
}

variable "github_repository" {
  description = "The only GitHub repository (owner/name) allowed to use this identity."
  type        = string
  default     = "matheuslab-bit/google-cloud-portfolio"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in the owner/name format."
  }
}

variable "state_bucket" {
  description = "Terraform state bucket from Lab 03. CI needs to create and delete the .tflock object during plan."
  type        = string
  default     = "gcp-portfolio-tfstate-usc1-7f4e9a2c"
}
