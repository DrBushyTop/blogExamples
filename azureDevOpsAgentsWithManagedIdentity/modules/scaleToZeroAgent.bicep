@description('''A name must consist of lower case alphanumeric characters or '-', start with an alphabetic character, and end with an alphanumeric character
and cannot have '--'. The length must not be more than 32 characters.''')
@maxLength(32)
param appName string
param environmentId string
@secure()
param azureDevOpsPAT string
param azureDevOpsOrgUrl string
param azureDevOpsAgentPoolName string
@description('The container image to use for the agent. Should be in format <registry>/<image>:<tag>')
param agentContainerImage string

param workloadProfileName string

@description('The maximum number of replicas to run in parallel')
param parallelism int

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

resource agentJob 'Microsoft.App/jobs@2023-05-01' = {
  name: replace(toLower(appName), '--', '-')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    workloadProfileName: workloadProfileName
    environmentId: environmentId
    configuration: {
      secrets: [
        {
          name: 'azure-devops-pat'
          value: azureDevOpsPAT
        }
        {
          name: 'azure-devops-org-url'
          value: azureDevOpsOrgUrl
        }
        {
          name: 'azure-devops-agent-pool-name'
          value: azureDevOpsAgentPoolName
        }
      ]
      registries: [
        {
          server: registryLoginServer
          identity: userAssignedIdentity.id
        }
      ]
      replicaTimeout: 1800
      replicaRetryLimit: 1
      triggerType: 'Event'
      eventTriggerConfig: {
        parallelism: parallelism
        replicaCompletionCount: 1
        scale: {
          pollingInterval: 10
          rules: [
            {
              name: 'azure-pipelines'
              type: 'azure-pipelines'
              metadata: {
                poolName: azureDevOpsAgentPoolName
                targetPipelinesQueueLength: '1' //  If one pod can handle 10 jobs, set the queue length target to 10. If the actual number of jobs in the queue is 30, the scaler scales to 3 pods.
                activationTargetPipelinesQueueLength: '0' // Target value for activating the scaler. Learn more about activation https://keda.sh/docs/2.12/concepts/scaling-deployments/#activating-and-scaling-thresholds .(Default: 0, Optional)
              }
              auth: [
                {
                  secretRef: 'azure-devops-pat'
                  triggerParameter: 'personalAccessToken'
                }
                {
                  secretRef: 'azure-devops-org-url'
                  triggerParameter: 'organizationURL'
                }
              ]
            }
          ]
        }
      }
    }
    template: {
      containers: [
        {
          name: 'devopsagent'
          image: agentContainerImage
          args: [// Shut down agent after each job
            '--once'
          ]
          env: [
            {
              name: 'AZP_TOKEN'
              secretRef: 'azure-devops-pat'
            }
            {
              name: 'AZP_URL'
              secretRef: 'azure-devops-org-url'
            }
            {
              name: 'AZP_POOL'
              secretRef: 'azure-devops-agent-pool-name'
            }
          ]
          resources: {
            cpu: any('1.25') // Need more than 1 core to enable 8GB of ephemeral storage
            memory: '5.3Gi'
          }
        }
      ]
    }
  }
}

var placeHolderScript = '''
## If you are creating this agent pool for the first time, you will need to create a placeholder agent run there. Do it with this script.

$AZP_TOKEN=REPLACEME

az containerapp job create -n "placeholder" -g RGNAME --environment ENVNAME \
    --trigger-type Manual \
    --replica-timeout 300 \
    --replica-retry-limit 1 \
    --replica-completion-count 1 \
    --parallelism 1 \
    --image "IMAGENAME" \
    --cpu "2.0" \
    --memory "4Gi" \
    --secrets "azure-devops-pat=$AZP_TOKEN" "azure-devops-org-url=ORGURL "azure-devops-agent-pool-name=POOLNAME\
    --env-vars "AZP_TOKEN=secretref:azure-devops-pat" "AZP_URL=secretref:azure-devops-org-url" "AZP_POOL=secretref:azure-devops-agent-pool-name" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=placeholder-agent" \
    --registry-server "REGISTRYLOGINSERVER"

az containerapp job start -n placeholder -g RGNAME

az containerapp job execution list \
    --name placeholder \
    --resource-group "RGNAME" \
    --output table \
    --query '[].{Status: properties.status, Name: name, StartTime: properties.startTime}'

## az containerapp job delete -n placeholder -g RGNAME
'''
// 🤮
var replacedScript = replace(replace(replace(replace(replace(replace(placeHolderScript, 'RGNAME', resourceGroup().name), 'ENVNAME', last(split(environmentId, '/'))), 'IMAGENAME', agentContainerImage), 'ORGURL', azureDevOpsOrgUrl), 'POOLNAME', azureDevOpsAgentPoolName), 'REGISTRYLOGINSERVER', registryLoginServer)
output createPlaceHolderAgent string = replacedScript

output scaledAgentName string = agentJob.name
