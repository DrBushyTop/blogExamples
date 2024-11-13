param vnetName string
param vnetAddressSpace string
param location string = 'swedencentral'

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'managedPool'
        properties: {
          addressPrefix: vnetAddressSpace
          delegations: [
            {
              name: 'Microsoft.DevOpsInfrastructure.Pools'
              properties: {
                serviceName: 'Microsoft.DevOpsInfrastructure/pools'
              }
            }
          ]
        }
      }
    ]
  }
}

// These are required permissions for the "DevOpsInfrastructure" app registration objectid 3172bc25-fa41-45bd-9605-dac44334ef33
var devOpsInfrastructureObjectId = '3172bc25-fa41-45bd-9605-dac44334ef33'

resource vnetReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('vnetReader-${vnetName}-${devOpsInfrastructureObjectId}')
  scope: vnet
  properties: {
    principalId: devOpsInfrastructureObjectId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    ) // Reader
    principalType: 'ServicePrincipal'
  }
}

resource networkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('vnetContributor-${vnetName}-${devOpsInfrastructureObjectId}')
  scope: vnet
  properties: {
    principalId: devOpsInfrastructureObjectId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor
    principalType: 'ServicePrincipal'
  }
}

output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
