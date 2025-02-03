param location string = resourceGroup().location

param appPlanName string = '${uniqueString(resourceGroup().id)}plan'

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

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${appServicePlan.name}storage'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Premium_LRS'
  }
}
