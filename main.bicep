var opsystemTag = 'v1.0.3'
var resourceGroupLocation = resourceGroup().location
var resourceSuffix = uniqueString(subscription().subscriptionId, resourceGroup().name)

var appPlanName = 'opsystemappserver-${resourceSuffix}'
var webAppName = 'opsystemwebapp-${resourceSuffix}'
var storageAccountName = substring('opsystemstorage${resourceSuffix}', 0, 24)
var pgDbName = 'opsystemdbserver-${resourceSuffix}'
var pgDbAdminUserName = 'opsystemdbadmin'
var redisCacheName = 'opsystemcache-${resourceSuffix}'
param buildPostgres bool = true
param buildRedis bool = true
@secure()
param pgDbAdminPassword string
@secure()
param jwtSecret string

@allowed([
  'F1'
  'B1'
  'S1'
  'P1V2'
])
param skuName string = 'F1'

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appPlanName
  location: resourceGroupLocation
  kind: 'app,linux'
  properties: {
    reserved: true

  }
  sku: {
    name: skuName
    capacity: 1
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: resourceGroupLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource fileservice 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {  
  parent: storageaccount
  name: 'default'  
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileservice
  name: 'opfiles'
}

resource postgresqlDbServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = if (buildPostgres) {
  name: pgDbName
  location: resourceGroupLocation
  sku: {
    tier: 'Burstable'
    name: 'Standard_B2s'
  }
  properties: {
    version: '16'
    storage: {
      iops: 120
      tier: 'P4'
      storageSizeGB: 32
      autoGrow: 'Disabled'
    }
    administratorLogin: pgDbAdminUserName
    administratorLoginPassword: pgDbAdminPassword
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }  
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-11-01-preview' = if (buildPostgres) {
  parent: postgresqlDbServer
  name: 'opsystem'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

resource pgDbFwRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (buildPostgres) {
  parent: postgresqlDbServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource redisCache 'Microsoft.Cache/Redis@2024-04-01-preview' = if (buildRedis) {
  name: redisCacheName
  location: resourceGroupLocation
  properties: {
    redisVersion: '6'
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'    
    publicNetworkAccess: 'Enabled'    
    updateChannel: 'Stable'
    disableAccessKeyAuthentication: false
  }
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: resourceGroupLocation
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }  
  properties: {    
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: true
    httpsOnly: true
    siteConfig: {
      webSocketsEnabled: true
      linuxFxVersion: 'DOCKER|opsystemcr.azurecr.io/opsystem:${opsystemTag}'
      acrUseManagedIdentityCreds: false
      azureStorageAccounts: {
        opfiles: {
          accountName: storageaccount.name
          shareName: fileshare.name
          accessKey: storageaccount.listKeys().keys[0].value
          mountPath: '/opfiles'
          type: 'AzureFiles'          
        }
      }
      appSettings: [
        {
          name: 'APP_HOST'
          value: '0.0.0.0'
        }
        {
          name: 'APP_PORT'
          value: '3000'
        }
        {
          name: 'DATABASE_URL'
          value: (buildPostgres) ? 'postgresql://${pgDbAdminUserName}:${pgDbAdminPassword}@${postgresqlDbServer.properties.fullyQualifiedDomainName}/${postgresDatabase.name}' : ''
        }
        {
          name: 'REDIS_URL'
          value: (buildRedis) ? 'rediss://:${redisCache.listKeys().primaryKey}@${redisCache.properties.hostName}:6380' : ''
        }
        {
          name: 'JWT_SECRET'
          value: jwtSecret
        }
        {
          name: 'ADB2C_AUTHORITY_DOMAIN'
          value: ''
        }
        {
          name: 'ADB2C_TENANT_ID'
          value: ''
        }
        {
          name: 'ADB2C_TENANT_NAME'
          value: ''
        }
        {
          name: 'ADB2C_POLICY_NAME'
          value: ''
        }
        {
          name: 'ADB2C_CLIENT_ID'
          value: ''
        }
        {
          name: 'ADB2C_CLIENT_SECRET'
          value: ''
        }
        {
          name: 'ADB2C_REDIRECT_URI'
          value: ''
        }
        {
          name: 'ADB2C_SCOPES'
          value: 'openid profile'
        }
        {
          name: 'FILE_IO_ROOT'
          value: '/opfiles'
        }
        {
          name: 'DEFAULT_IDP'
          value: 'adb2c'
        }
        {
          name: 'SENDGRID_API_KEY'
          value: ''
        }
        {
          name: 'SENDGRID_FROM_EMAIL'
          value: ''
        }
        {
          name: 'BASE_APPLICATION_URL'
          value: ''
        }
        {
          name: 'OP_IMPORT_CLI_PATH'
          value: '/usr/local/bin/opimport-cli/opimport-cli.py'
        }
        {
          name: 'LICENSE_KEY'
          value: ''
        }
        {
          name: 'CRM_TENANT_ID'
          value: ''
        }
        {
          name: 'CRM_CLIENT_ID'
          value: ''
        }
        {
          name: 'CRM_CLIENT_SECRET'
          value: ''
        }
        {
          name: 'CRM_CLIENT_SCOPE'
          value: ''
        }
        {
          name: 'CRM_BASE_API_URL'
          value: ''
        }
        {
          name: 'FIRST_ADMIN_EMAIL'
          value: ''
        }
      ]
    }
  }
}

output defaultHostName string = webApplication.properties.defaultHostName
