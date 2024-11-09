param keyvaultName string
param location string

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyvaultName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Enabled'
    enableRbacAuthorization: true
  }
}

resource kvExampleSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'hellosecret'
  parent: keyvault
  properties: {
    value: 'Hello CloudBrew!' // Ultrasecure
  }
}

output keyvaultName string = keyvault.name
output keyvaultId string = keyvault.id
output kvExampleSecretName string = kvExampleSecret.name
