// EntraId setup Kubelle?

extension microsoftGraphV1_0

@description('The created service principal will be given permissions to this key vault. Your identity will need to have required permissions.')
param keyVaultResourceId string

param issuer string
param subject string

resource appReg 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'phcloudbrewkubeid'
  uniqueName: 'phcloudbrewkubeid'
  identifierUris: [
    'api://phcloudbrewkubeid'
  ]
  signInAudience: 'AzureADMyOrg'
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        {
          // User.Read
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
          type: 'Scope'
        }
      ]
    }
  ]
}

resource appRegSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: appReg.id
}

resource federation 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: 'KubeFederation'
  parent: appReg
  properties: {
    issuer: // TODO
    subject: // TODO
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

output clientId string = appReg.id
output tenantId string = tenant().tenantId
output audience string = appReg.signInAudience

var kubeConfigMap = '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: identity
  namespace: cloudbrewapp
data:
  AZURE_TENANT_ID: REPLACE_TENANT_ID
  AZURE_CLIENT_ID: REPLACE_CLIENT_ID
'''
output kubeConfigMap string = replace(
  replace(kubeConfigMap, 'REPLACE_TENANT_ID', tenant().tenantId),
  'REPLACE_CLIENT_ID',
  appReg.id
)
