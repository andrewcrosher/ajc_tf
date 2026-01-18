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
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}