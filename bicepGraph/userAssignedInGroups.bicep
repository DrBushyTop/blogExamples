extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.8-preview'

resource identity1 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'identity1'
  location: 'swedencentral'
}

resource identity2 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'identity2'
  location: 'swedencentral'
}

resource group 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'bicepDemoGroup'
  mailEnabled: false
  mailNickname: 'bicepDemoGroup'
  securityEnabled: true
  uniqueName: 'bicepDemoGroup'
  members: [
    identity1.properties.principalId
    identity2.properties.principalId
  ]
}

// Proceed to give permissions to group...
