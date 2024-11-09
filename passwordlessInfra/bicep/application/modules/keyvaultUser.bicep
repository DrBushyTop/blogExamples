param keyVaultName string
param identityPrincipalId string
@allowed([
  'ServicePrincipal'
  'Group'
  'ForeignGroup'
  'User'
])
param principalType string = 'ServicePrincipal'
@allowed([
  'Key Vault Administrator'
  'Key Vault Secrets User'
])
param role string

var roleIds = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${keyVault.id}-${identityPrincipalId}-${roleIds[role]}')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[role])
    principalId: identityPrincipalId
    principalType: principalType
  }
}
