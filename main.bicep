param location string = resourceGroup().location

param defaultName string = 'op-${subscription().displayName}'
param appPlanName string = 'asp-${defaultName}'
param webAppName string = 'webapp-${defaultName}'
param storageAccountName string = 'sa-${defaultName}'

@allowed([
  'F1'
  'B1'
  'S1'
  'P1V2'
])
param skuName string = 'F1'

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appPlanName
  location: location
  sku: {
    name: skuName
    capacity: 1
  }
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }  
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: true
    httpsOnly: true
    siteConfig: {
      webSocketsEnabled: true
      linuxFxVersion: 'DOCKER|opsystemcr.azurecr.io/opsystem:v1.0.3'
    }
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Premium_LRS'
  }
}
