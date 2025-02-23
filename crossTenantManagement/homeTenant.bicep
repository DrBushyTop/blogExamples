extension microsoftGraphV1

param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'b2cAutomation-uai'
  location: location
}

resource myApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'Multi-Tenant Example App'
  uniqueName: 'b2cAutomation'
  signInAudience: 'AzureADMultipleOrgs' // Important for multi-tenant apps

  resource myMsiFic 'federatedIdentityCredentials@v1.0' = {
    name: 'b2cAutomation/${managedIdentity.name}'
    description: 'Federated Identity Credentials for Managed Identity'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
    subject: managedIdentity.properties.principalId
  }
}

output appRegClientId string = myApp.appId
