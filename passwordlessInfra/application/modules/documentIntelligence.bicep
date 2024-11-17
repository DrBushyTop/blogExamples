param documentIntelligenceName string
param location string
param sku string = 'S0'

param dataLakeResourceId string

param adminGroupObjectId string

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: documentIntelligenceName
  location: location
  kind: 'FormRecognizer'
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: toLower(documentIntelligenceName)
    publicNetworkAccess: 'Enabled'
  }
}

var dataLakeResourceGroupName = split(dataLakeResourceId, '/')[4]
var dataLakeName = last(split(dataLakeResourceId, '/'))

// This probably does not yet get used anywhere. The code generates a SAS token instead.
module dataLakeUser 'dataLakeUser.bicep' = {
  name: 'dataLakeUser-processor-${last(split(deployment().name, '-'))}'
  params: {
    identityPrincipalId: documentIntelligence.identity.principalId
    role: 'Storage Blob Data Reader'
    storageAccountName: dataLakeName
  }
  scope: resourceGroup(dataLakeResourceGroupName)
}

module documentIntelligenceUser_developers 'documentIntelligenceUser.bicep' = {
  name: 'documentIntelligenceUser-devs${last(split(deployment().name, '-'))}'
  params: {
    identityPrincipalId: adminGroupObjectId
    documentIntelligenceName: documentIntelligenceName
    role: 'Cognitive Services User'
    principalType: 'Group'
  }
}

output documentIntelligenceName string = documentIntelligence.name
output documentIntelligenceEndpoint string = documentIntelligence.properties.endpoint
output documentIntelligenceResourceId string = documentIntelligence.id
