variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "project_name" {
  description = "Project prefix"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget in INR"
  type        = number
  default     = 700
}

variable "aks_node_count" {
  description = "Number of AKS worker nodes"
  type        = number
  default     = 1
}
