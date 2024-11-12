param location string = 'westeurope'
param adoOrgName string
param poolName string = 'phManagedPool'
param poolSize int = 1

module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    vnetAddressSpace: '10.26.3.0/24'
    vnetName: 'managedPoolVnet'
  }
}

module devcenterAndProject 'modules/devcenter.bicep' = {
  name: 'devcenterAndProject'
  params: {
    location: location
  }
}

module managedPool 'modules/pool.bicep' = {
  name: 'managedPool'
  params: {
    adoOrgName: adoOrgName
    devCenterProjectResourceId: devcenterAndProject.outputs.projectId
    poolName: poolName
    poolSize: poolSize
    subnetResourceId: vnet.outputs.subnetId
  }
}
