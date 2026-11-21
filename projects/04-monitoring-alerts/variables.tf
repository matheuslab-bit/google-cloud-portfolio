variable "project_id" {
  description = "Google Cloud project ID that is monitored and covered by the budget."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID (6 to 30 lowercase letters, digits, or hyphens)."
  }
}

variable "alert_email" {
  description = "E-mail address that receives alerts and budget notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid e-mail address."
  }
}

variable "billing_account" {
  description = "Billing account ID linked to the project (format XXXXXX-XXXXXX-XXXXXX)."
  type        = string

  validation {
    condition     = can(regex("^[A-F0-9]{6}-[A-F0-9]{6}-[A-F0-9]{6}$", var.billing_account))
    error_message = "billing_account must look like 012345-6789AB-CDEF01."
  }
}

variable "monthly_budget" {
  description = "Monthly budget amount, in the billing account currency."
  type        = number
  default     = 20

  validation {
    condition     = var.monthly_budget > 0
    error_message = "monthly_budget must be greater than zero."
  }
}

variable "currency_code" {
  description = "Billing account currency (ISO 4217). Must match the billing account, or the API rejects the budget."
  type        = string
  default     = "BRL"

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.currency_code))
    error_message = "currency_code must be a three-letter ISO 4217 code, such as BRL or USD."
  }
}

variable "vm_instance_name" {
  description = "Name of the VM watched by the CPU and availability alerts (the Lab 02 VM)."
  type        = string
  default     = "lab02-secure-vm"
}

variable "cpu_threshold" {
  description = "CPU utilization (0 to 1) that opens an incident when sustained for 5 minutes."
  type        = number
  default     = 0.8

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold < 1
    error_message = "cpu_threshold must be between 0 and 1 (for example 0.8 for 80%)."
  }
}
