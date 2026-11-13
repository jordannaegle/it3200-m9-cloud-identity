variable "subscription_id" {
  description = "Personal Azure subscription for this lab."
  type        = string
}

variable "tenant_id" {
  description = "Personal Microsoft Entra tenant."
  type        = string
}

variable "location" {
  description = "Azure deployment region."
  type        = string
  default     = "westus3"
}

variable "student_name" {
  description = "Student name used in resource names."
  type        = string
  default     = "jordan"
}

variable "storage_account_name" {
  description = "Globally unique name using 3–24 lowercase letters and numbers."
  type        = string
}

variable "container_name" {
  description = "Private container for test reports."
  type        = string
  default     = "reports"
}