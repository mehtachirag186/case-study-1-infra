resource "time_static" "now" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "cs1-budget"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", time_static.now.rfc3339)
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = ["mehtachirag186@gmail.com"]
  }
}
resource "azurerm_virtual_network" "this" {
  name                = "${var.project_name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
}
resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.project_name}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${var.project_name}-dns"

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.aks.id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }
}
