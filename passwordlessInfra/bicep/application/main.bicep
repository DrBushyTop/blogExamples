// TODO: Ehkä datalaken palomuuri kiinni ja vaan DI resurssina pääsee sisään?
// VNET, VM, tagilla jotain sisään. RDP auki. 
// App Service SQLiin oikeudet

param namingPrefix string = 'phcloudbrew'
param location string = 'swedencentral'
param adminGroupObjectId string //TODO

var naming = {
  law: '${namingPrefix}-law'
  appInsights: '${namingPrefix}-appinsights'
  keyVault: '${namingPrefix}kv'
  vm: '${namingPrefix}-vm'
  storage: '${namingPrefix}stg'
  sqlServer: '${namingPrefix}-sql'
  sqlDatabase: '${namingPrefix}-sqldb'
  appService: '${namingPrefix}-appservice'
  appServicePlan: '${namingPrefix}-appserviceplan'
  documentIntelligence: '${namingPrefix}-di'
  serviceBus: '${namingPrefix}-sbus'
  functionApp: '${namingPrefix}-func'
  functionIdentity: '${namingPrefix}-func-id'
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    keyvaultName: naming.keyVault
    location: location
  }
}

module telemetry 'modules/telemetry.bicep' = {
  name: 'telemetry'
  params: {
    lawName: naming.law
    appInsightsName: naming.appInsights
    keyVaultName: keyvault.outputs.keyvaultName
    location: location
  }
}

module data 'modules/data.bicep' = {
  name: 'data'
  params: {
    datalakeName: naming.storage
    sqlServerName: naming.sqlServer
    sqlDatabaseName: naming.sqlDatabase
    location: location
    keyVaultName: naming.keyVault
    adminGroupObjectId: adminGroupObjectId
  }
}

module documentIntelligence 'modules/documentIntelligence.bicep' = {
  name: 'documentIntelligence'
  params: {
    documentIntelligenceName: naming.documentIntelligence
    location: location
    logAnalyticsResourceId: telemetry.outputs.lawId
    adminGroupObjectId: adminGroupObjectId
    dataLakeResourceId: data.outputs.dataLakeId
  }
}

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    appServiceName: naming.appService
    appServicePlanName: naming.appServicePlan
    location: location

    keyVaultName: keyvault.outputs.keyvaultName
    appInsightsCstringKeyVaultRef: telemetry.outputs.appInsightsCstringKeyVaultRef
    sqlConnectionStringKeyVaultRef: data.outputs.sqlCstringKeyVaultRef
  }
}

module serviceBus 'modules/serviceBusFunc.bicep' = {
  name: 'serviceBusAndFunction'
  params: {
    serviceBusName: naming.serviceBus

    funcAppName: naming.functionApp
    funcStorageAccountName: data.outputs.dataLakeName
    funcUserAssignedIdentityName: naming.functionIdentity
    aiCstringKeyVaultRef: telemetry.outputs.appInsightsCstringKeyVaultRef
    appServicePlanId: appService.outputs.appServicePlanId
    keyVaultName: keyvault.outputs.keyvaultName

    location: location
    adminGroupObjectId: adminGroupObjectId
  }
}
