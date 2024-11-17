param devCenterName string = 'devopspoolcenter'
param projectName string = 'manageddevopspools'
param location string = 'swedencentral'

resource devcenter 'Microsoft.DevCenter/devcenters@2024-10-01-preview' = {
  name: devCenterName
  location: location
  properties: {}
}

resource project 'Microsoft.DevCenter/projects@2024-10-01-preview' = {
  name: projectName
  location: location
  properties: {
    devCenterId: devcenter.id
    description: 'Managed DevOps Pools'
  }
}

output devCenterId string = devcenter.id
output projectId string = project.id
