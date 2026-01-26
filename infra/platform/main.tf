resource "azurerm_container_registry" "this" {
  name                = "${var.project_name}acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project_name}-aks"
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = data.azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.this.id
}
