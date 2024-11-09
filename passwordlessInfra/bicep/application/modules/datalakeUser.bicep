param storageAccountName string
param identityPrincipalId string
@allowed([
  'ServicePrincipal'
  'Group'
  'ForeignGroup'
  'User'
])
param principalType string = 'ServicePrincipal'
@allowed([
  'Storage Blob Data Owner'
  'Storage Blob Data Contributor'
  'Storage Blob Data Reader'
  'Storage Queue Data Contributor'
  'Storage Account Contributor'
])
param role string

var roleIds = {
  'Storage Blob Data Owner': 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  'Storage Blob Data Contributor': 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'Storage Blob Data Reader': '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  'Storage Queue Data Contributor': '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  'Storage Account Contributor': '17d1049b-9a84-46fb-8f53-869881c3d3ab'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource dataLakeRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${storageAccount.id}-${identityPrincipalId}-${roleIds[role]}')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[role])
    principalId: identityPrincipalId
    principalType: principalType
  }
}
