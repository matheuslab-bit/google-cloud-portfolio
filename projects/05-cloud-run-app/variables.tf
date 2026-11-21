variable "project_id" {
  description = "Google Cloud project ID where the Cloud Run lab is created."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID (6 to 30 lowercase letters, digits, or hyphens)."
  }
}

variable "region" {
  description = "Region for Artifact Registry and Cloud Run. us-central1 is covered by the Cloud Run free tier."
  type        = string
  default     = "us-central1"
}

variable "image" {
  description = "Full image path to deploy (REGION-docker.pkg.dev/PROJECT/apps/status-api:TAG). Leave empty on the first apply: only the registry, secret and service account are created."
  type        = string
  default     = ""

  validation {
    condition     = var.image == "" || can(regex("^[a-z0-9-]+-docker\\.pkg\\.dev/.+/.+:.+$", var.image))
    error_message = "image must be an Artifact Registry path with a tag, or empty."
  }
}

variable "allow_public_access" {
  description = "When true, anyone on the internet can call the service. Keep false and call it with an identity token."
  type        = bool
  default     = false
}

variable "max_instances" {
  description = "Upper limit of instances. A low cap protects the bill if the service gets unexpected traffic."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 10
    error_message = "max_instances must be between 1 and 10 for this lab."
  }
}
