param uaiName string = 'DevOpsServiceConnectionUAI'
param location string = 'westeurope'
param issuer string
param subjectIdentifier string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: uaiName
  location: location
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-07-31-preview' = {
  name: 'AzureDevOpsFederation'
  parent: userAssignedIdentity
  properties: {
    subject: subjectIdentifier
    issuer: issuer
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

output tenantId string = subscription().tenantId
output clientId string = userAssignedIdentity.properties.clientId
output subscriptionId string = subscription().subscriptionId
output subscriptionName string = subscription().displayName
