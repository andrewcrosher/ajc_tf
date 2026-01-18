variable "location" {
  description = "Azure region for the resources"
  type        = string
  default     = "uksouth"
}

variable "resource_prefix" {
  description = "Prefix for naming Azure resources"
  type        = string
  default     = "ajc"
  validation {
    condition     = length(var.resource_prefix) <= 10
    error_message = "Resource prefix must be 10 characters or less to ensure all resource names, including the storage account (${var.resource_prefix}${var.environment}datalakesa), stay within Azure's 24 character limit."
  }
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