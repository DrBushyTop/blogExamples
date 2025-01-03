// TODO: Ehkä datalaken palomuuri kiinni ja vaan DI resurssina pääsee sisään?
// VNET, VM, tagilla jotain sisään. SSH auki, HTTPS auki? Jos tää VM vaikka ajais kubeklusteria minikubessa. Toinen storage tälle?
// App Service SQLiin oikeudet
// TODO: App servicelle storage oikeudet

param namingPrefix string = 'phcloudbrew'
param location string = 'swedencentral'
param adminGroupObjectId string //TODO
@description('The SSH public key to use for the VM. If omitted, VM and relevant resources will not be deployed')
param sshPublicKey string

var naming = {
  law: '${namingPrefix}-law'
  appInsights: '${namingPrefix}-appinsights'
  keyVault: '${namingPrefix}kv'
  vm: '${namingPrefix}-vm'
  vnet: '${namingPrefix}-vnet'
  storage: '${namingPrefix}stg'
  sqlServer: '${namingPrefix}-sql'
  sqlDatabase: '${namingPrefix}-sqldb'
  appService: '${namingPrefix}-appservice'
  appServicePlan: '${namingPrefix}-appserviceplan'
  documentIntelligence: '${namingPrefix}-di'
  serviceBus: '${namingPrefix}-sbus'
  functionApp: '${namingPrefix}-func'
  functionStorage: '${namingPrefix}fustg'
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
    keyVaultName: keyvault.outputs.keyvaultName
    adminGroupObjectId: adminGroupObjectId
  }
}

module documentIntelligence 'modules/documentIntelligence.bicep' = {
  name: 'documentIntelligence'
  params: {
    documentIntelligenceName: naming.documentIntelligence
    location: location
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
    funcStorageAccountName: naming.functionStorage
    funcUserAssignedIdentityName: naming.functionIdentity
    aiCstringKeyVaultRef: telemetry.outputs.appInsightsCstringKeyVaultRef
    appServicePlanId: appService.outputs.appServicePlanId
    keyVaultName: keyvault.outputs.keyvaultName

    location: location
    adminGroupObjectId: adminGroupObjectId
  }
}

module vmStuff 'modules/vmStuff.bicep' = if (sshPublicKey != '') {
  name: 'vmStuff'
  params: {
    vmName: naming.vm
    vnetName: naming.vnet
    vnetAddressSpace: '10.89.1.0/24'
    location: location
    sshPublicKey: sshPublicKey
  }
}

output keyVaultResourceId string = keyvault.outputs.keyvaultId
output vmPublicIp string = vmStuff.outputs.vmPublicIp
