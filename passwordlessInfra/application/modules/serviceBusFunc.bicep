param serviceBusName string

param funcAppName string
@description('The resource id of the app service plan to place function on. Note only non-consumption plans work as passwordless requires a dedicated plan')
param appServicePlanId string
param funcUserAssignedIdentityName string
param funcStorageAccountName string
param keyVaultName string
param aiCstringKeyVaultRef string

param location string
param adminGroupObjectId string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
}

resource queue_process 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: 'somequeue'
  parent: serviceBus
  properties: {
    status: 'Active'
    requiresSession: false
    maxDeliveryCount: 3
  }
}

module adminSbusOwner 'serviceBusUser.bicep' = {
  name: 'admingroup-sbusowner-${last(split(deployment().name, '-'))}'
  params: {
    serviceBusName: serviceBus.name
    principalType: 'Group'
    identityPrincipalId: adminGroupObjectId
    role: 'Azure Service Bus Data Owner'
  }
}

// FUNCTION STUFF

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: funcUserAssignedIdentityName
  location: location
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: funcStorageAccountName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

resource function 'Microsoft.Web/sites@2023-12-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      use32BitWorkerProcess: false
      http20Enabled: true
      netFrameworkVersion: 'v8.0'
    }
    clientAffinityEnabled: false
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
}

resource appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'appsettings'
  parent: function
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: aiCstringKeyVaultRef
    DiagnosticServices_EXTENSION_VERSION: '~3'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    SnapshotDebugger_EXTENSION_VERSION: '~2'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    ENVIRONMENT: 'AzureProduction'
    WEBSITE_RUN_FROM_PACKAGE: '1'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    AzureWebJobsStorage__accountname: funcStorageAccountName
    ServiceBusConnection__fullyQualifiedNamespace: '${serviceBus.name}.servicebus.windows.net'

    // Needed as we only have a user assigned identity
    AzureWebJobsStorage__credential: 'managedIdentity'
    AzureWebJobsStorage__clientId: userAssignedIdentity.properties.principalId
    ServiceBusConnection__clientId: userAssignedIdentity.properties.principalId // These are important for continued functionality. Without them it might look like the function is pulling items, but it only stays awake for a while and then stops working until you visit the portal or run the sync again
    ServiceBusConnection__credential: 'managedIdentity'
    AZURE_CLIENT_ID: userAssignedIdentity.properties.principalId // This is for DefaultAzureCredential and the like to not have to specify ID in code
  }
}

module funcSbusOwner 'serviceBusUser.bicep' = {
  name: '${funcUserAssignedIdentityName}-sbusowner-${last(split(deployment().name, '-'))}'
  params: {
    serviceBusName: serviceBus.name
    principalType: 'Group'
    identityPrincipalId: adminGroupObjectId
    role: 'Azure Service Bus Data Owner'
  }
}

module funcKvUser 'keyvaultUser.bicep' = {
  name: 'kvPermissions'
  params: {
    keyVaultName: keyVaultName
    identityPrincipalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    role: 'Key Vault Secrets User'
  }
}

module funcStorageAccContributor 'datalakeUser.bicep' = {
  name: '${funcUserAssignedIdentityName}-stgaccctr-${last(split(deployment().name, '-'))}'
  params: {
    storageAccountName: funcStorageAccountName
    identityPrincipalId: userAssignedIdentity.properties.principalId
    role: 'Storage Account Contributor'
  }
}

module funcStorageBlobOwner 'datalakeUser.bicep' = {
  name: '${funcUserAssignedIdentityName}-stgblobowner-${last(split(deployment().name, '-'))}'
  params: {
    storageAccountName: funcStorageAccountName
    identityPrincipalId: userAssignedIdentity.properties.principalId
    role: 'Storage Blob Data Owner'
  }
}

module funcStorageQueueContributor 'datalakeUser.bicep' = {
  name: '${funcUserAssignedIdentityName}-stgqueuectr-${last(split(deployment().name, '-'))}'
  params: {
    storageAccountName: funcStorageAccountName
    identityPrincipalId: userAssignedIdentity.properties.principalId
    role: 'Storage Queue Data Contributor'
  }
}

output serviceBusName string = serviceBus.name
output serviceBusResourceId string = serviceBus.id

output processQueueName string = queue_process.name
