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

output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
