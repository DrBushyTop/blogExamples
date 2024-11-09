param lawName string
param appInsightsName string
param location string

param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
  }
}

resource appInsightsCstring 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'AppInsightsConnectionString'
  parent: keyVault
  properties: {
    value: appInsights.properties.ConnectionString
  }
}

output lawName string = law.name
output appInsightsName string = appInsights.name
output lawId string = law.id
output appInsightsId string = appInsights.id
output appInsightsCstringKeyVaultRef string = '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/${appInsightsCstring.name})'
