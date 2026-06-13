terraform {
  required_version = ">= 1.1.0"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }

  }
}

provider "azurerm" {
  features {}
}

provider "cloudinit" {
}

variable "labelPrefix" {
  description = "Your college username"
}

variable "region" {
  default = "canadacentral"
}

variable "admin_username" {
  default = "azureadmin"
}

resource "azurerm_resource_group" "rg" {

  name     = "${var.labelPrefix}-A05-RG"
  location = var.region

}