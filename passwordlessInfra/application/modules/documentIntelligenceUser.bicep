// This template has been split from the main API template to allow use of principalID in the assignment name.
// This avoids having to delete the previous assignment from the vault if API web app or function has been recreated
// Also supports resources in separate resource groups, though use there always creates a semi-invisible dependency

param documentIntelligenceName string
param identityPrincipalId string
@allowed(
  [
    'ServicePrincipal'
    'Group'
    'ForeignGroup'
    'User'
  ]
)
param principalType string = 'ServicePrincipal'
@allowed(
  [
    'Cognitive Services User'
    'Cognitive Services Custom Vision Contributor'
  ]
)
param role string

var roleIds = {
  'Cognitive Services Custom Vision Contributor': 'c1ff6cc2-c111-46fe-8896-e0ef812ad9f3' // Not sure if this role is needed somewhere
  'Cognitive Services User': 'a97b65f3-24c7-4388-baec-2e87135dc908'
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' existing = {
  name: documentIntelligenceName
}

resource documentIntelligenceRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${documentIntelligence.id}-${identityPrincipalId}-${roleIds[role]}')
  scope: documentIntelligence
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[role])
    principalId: identityPrincipalId
    principalType: principalType
  }
}
