param poolName string
param adoOrgName string
param devCenterProjectResourceId string
param imageName string = 'windows-2022'
@description('The number of agents in the pool')
param poolSize int
param vmSku string = 'Standard_D2ads_v5'
param location string = 'swedencentral'
@description('The resource ID of the Subnet to deploy the pool into. Needs to be delegated to Microsoft.DevOpsInfrastructures/pools')
param subnetResourceId string?

var adoOrgUrl = 'https://dev.azure.com/${adoOrgName}'

var networkProf = subnetResourceId != null
  ? {
      networkProfile: { subnetId: subnetResourceId! }
    }
  : {}

resource pool 'Microsoft.DevOpsInfrastructure/pools@2024-10-19' = {
  name: poolName
  location: location
  tags: {}
  properties: {
    organizationProfile: {
      organizations: [
        {
          url: adoOrgUrl
          parallelism: 1
        }
      ]
      permissionProfile: {
        kind: 'CreatorOnly'
      }
      kind: 'AzureDevOps'
    }
    devCenterProjectResourceId: devCenterProjectResourceId
    maximumConcurrency: poolSize
    agentProfile: {
      kind: 'Stateless'
    }
    fabricProfile: {
      ...networkProf
      sku: {
        name: vmSku
      }
      images: [
        {
          wellKnownImageName: imageName
          buffer: '*'
        }
      ]
      kind: 'Vmss'
    }
  }
}
