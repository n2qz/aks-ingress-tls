variable "email" {
  type        = string
  description = "Your email address"
}

variable "zone-name" {
  type        = string
  description = "The name of your Azure-managed DNS zone (e.g. example.com)"
}

variable "zone-rg" {
  type        = string
  description = "The name of your Azure resource group containing the managed DNS zone"
}

variable "ingress-subdomain-name" {
  type        = string
  description = "The subdomain (host) name to be assigned to the ingress controller"
}

variable "letsencrypt-acme-api" {
  type        = string
  description = "Which letsencrypt ACME API to use, production or staging"
  default     = "production"
}

variable "aks-name" {
  type        = string
  description = "Name of the AKS cluster to create"
  default     = "example"
}

variable "aks-rg-name" {
  type        = string
  description = "Name of the resource group to create for the AKS cluster"
  default     = "rg-example"
}

variable "aks-location" {
  type        = string
  description = "Location for the AKS cluster"
  default     = "eastus2"
}
