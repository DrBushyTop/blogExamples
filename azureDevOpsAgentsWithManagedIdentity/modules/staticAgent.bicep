@description('''A name must consist of lower case alphanumeric characters or '-', start with an alphabetic character, and end with an alphanumeric character
and cannot have '--'. The length must not be more than 32 characters.''')
@maxLength(32)
param appName string
param environmentId string

@secure()
param azureDevOpsPat string = ''
param azureDevOpsOrgUrl string
param azureDevOpsAgentPoolName string
@description('The container image to use for the agent. Should be in format <registry>/<image>:<tag>')
param agentContainerImage string

param workloadProfileName string

param numberOfAgents int = 3

@description('Registry login server and the admin username')
param registryLoginServer string

param registryPullerIdentityResourceId string

param location string

var identityName = last(split(registryPullerIdentityResourceId, '/'))
var identityRg = split(registryPullerIdentityResourceId, '/')[4]
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
  scope: resourceGroup(identityRg)
}

var defaultSecrets = [
  {
    name: 'azure-devops-org-url'
    value: azureDevOpsOrgUrl
  }
  {
    name: 'azure-devops-agent-pool-name'
    value: azureDevOpsAgentPoolName
  }
]

var patSecret = {
  name: 'azure-devops-pat'
  value: azureDevOpsPat
}

var defaultEnvVar = [
  {
    name: 'AZP_URL'
    secretRef: 'azure-devops-org-url'
  }
  {
    name: 'AZP_POOL'
    secretRef: 'azure-devops-agent-pool-name'
  }
]

var patEnvVar = {
  name: 'AZP_TOKEN'
  secretRef: 'azure-devops-pat'
}

var managedIdentityEnvVar = {
  // Adding this makes the agent use Managed identity tokens instead of PAT tokens
  name: 'MANAGED_IDENTITY_OBJECT_ID'
  value: userAssignedIdentity.properties.principalId
}

resource staticAgent 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: '${replace(toLower(appName), '--', '-')}-static'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: environmentId
    workloadProfileName: workloadProfileName
    configuration: {
      secrets: azureDevOpsPat != '' ? union(defaultSecrets, array(patSecret)) : defaultSecrets
      registries: [
        {
          server: registryLoginServer
          identity: userAssignedIdentity.id
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      scale: {
        minReplicas: numberOfAgents
        maxReplicas: numberOfAgents
      }
      containers: [
        {
          name: 'devopsagent'
          image: agentContainerImage
          env: azureDevOpsPat != '' ? union(defaultEnvVar, array(patEnvVar)) : union(defaultEnvVar, array(managedIdentityEnvVar))
          resources: {
            cpu: any('1.25') // Need more than 1 core to enable 8GB of ephemeral storage
            memory: '5.3Gi'
          }
        }
      ]
    }
  }
}
