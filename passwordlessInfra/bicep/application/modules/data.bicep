param datalakeName string
param sqlServerName string
param sqlDatabaseName string
param location string

param keyVaultName string
param adminGroupObjectId string
param changeAdmin bool = false

resource datalake 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: datalakeName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
  }

  resource blobService 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: 'data'
    }
  }
}

module dataLakeUser_developers 'dataLakeUser.bicep' = {
  name: 'dataLakeUser-devs-${last(split(deployment().name, '-'))}'
  params: {
    identityPrincipalId: adminGroupObjectId
    role: 'Storage Blob Data Owner'
    storageAccountName: datalake.name
    principalType: 'Group'
  }
}

var loginName = 'SQL Administrators'

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administrators: changeAdmin
      ? {}
      : {
          administratorType: 'ActiveDirectory'
          azureADOnlyAuthentication: true
          login: loginName
          principalType: 'Group'
          sid: adminGroupObjectId
          tenantId: subscription().tenantId
        }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: location
  sku: {
    capacity: 10
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Hack to get admin change working with only AAD admins allowed
resource sqlAdmins 'Microsoft.Sql/servers/administrators@2023-08-01-preview' = if (changeAdmin) {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    login: loginName
    administratorType: 'ActiveDirectory'
    sid: adminGroupObjectId
    tenantId: subscription().tenantId
  }
}
resource sqlAzureAdOnly 'Microsoft.Sql/servers/azureADOnlyAuthentications@2023-08-01-preview' = if (changeAdmin) {
  name: 'Default'
  parent: sqlServer
  properties: {
    azureADOnlyAuthentication: true
  }
  dependsOn: [
    sqlAdmins
  ]
}

resource sqlServer_masterDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  name: 'master'
  parent: sqlServer
  location: location
  properties: {}
}

resource sqlServer_allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource sqlConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'sqlConnectionString'
  parent: keyVault
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433; Authentication=Active Directory Default; Database=${sqlDatabase.name};'
  }
}

output dataLakeResourceId string = datalake.id
output dataLakeName string = datalake.name
output dataLakeId string = datalake.id

output dataLakeServiceUrl string = 'https://${datalake::blobService::container.name}@${datalakeName}.dfs.${az.environment().suffixes.storage}'
output dataLakeContainerName string = datalake::blobService::container.name

output sqlServerName string = sqlServer.name
output sqlServerId string = sqlServer.id
output sqlDatabaseName string = sqlDatabase.name
output sqlDatabaseId string = sqlDatabase.id
output sqlCstringKeyVaultRef string = '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/${sqlConnectionString.name})'
