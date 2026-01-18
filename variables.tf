variable "location" {
  description = "Azure region for the resources"
  type        = string
  default     = "uksouth"
}

variable "resource_prefix" {
  description = "Prefix for naming Azure resources"
  type        = string
  default     = "ajc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be either 'dev' or 'prd'."
  }
}