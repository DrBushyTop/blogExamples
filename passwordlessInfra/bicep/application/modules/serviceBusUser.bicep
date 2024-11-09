param serviceBusName string
param identityPrincipalId string
@allowed([
  'ServicePrincipal'
  'Group'
  'ForeignGroup'
  'User'
])
param principalType string = 'ServicePrincipal'
@allowed([
  'Azure Service Bus Data Sender'
  'Azure Service Bus Data Receiver'
  'Azure Service Bus Data Owner'
])
param role string

var roleIds = {
  'Azure Service Bus Data Sender': '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  'Azure Service Bus Data Receiver': '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  'Azure Service Bus Data Owner': '090c5cfd-751d-490a-894a-3ce6f1109419'
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2017-04-01' existing = {
  name: serviceBusName
}

resource serviceBusRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${serviceBus.id}-${identityPrincipalId}-${roleIds[role]}')
  scope: serviceBus
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[role])
    principalId: identityPrincipalId
    principalType: principalType
  }
}
