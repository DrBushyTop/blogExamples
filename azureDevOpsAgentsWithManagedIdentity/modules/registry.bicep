param containerRegistryName string
param pullerIdentityName string
param location string
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false // Admin user should not be needed with managed identity: https://learn.microsoft.com/en-us/azure/container-apps/containers#managed-identity-with-azure-container-registry
  }
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: pullerIdentityName
  location: location
}

// Assign AcrPull permission
module roleAssignment 'registrypermissions.bicep' = {
  name: 'container-registry-acrpull-role'
  params: {
    roleId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    principalId: identity.properties.principalId
    registryName: containerRegistry.name
  }
}

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
output pullerIdentityResourceId string = identity.id
