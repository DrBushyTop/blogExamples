// This deploys user assigned identity and configures Azure DevOps Service Connection.
// Requirements for this deployment:
// - Azure DevOps permissions to create service connections (Project Admin, Endpoint Administrator or Endpoint Creator)
// - Azure resource group already exists
// - Azure Subscription has following resource providers registered:
//   - Microsoft.Resources
//   - Microsoft.ManagedIdentity
//   - Microsoft.ContainerInstance
//   - Microsoft.Storage
// You should log in to the correct tenant before running this deployment using `Connect-AzAccount -TenantId <tenant-id>`
// Then get the access token using `$token = (Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" -AsSecureString).Token`
// Finally run:
// `New-AzResourceGroupDeployment -ResourceGroupName <resource-group-name> -TemplateFile .\main.bicep -TemplateParameterFile .\Production.params.bicep -AzureDevOpsSystemAccessToken $token`
// NOTE: This deployment will not grant the created service connection any permissions to the application's resource groups. You should do this manually after the deployment.
// For more info, check https://www.huuhka.net/user-assigned-managed-identities-with-azure-devops-service-connections/

param uaiName string

@secure()
@description('''Azure DevOps System Access Token. Can be fetched using "$token = (Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" -AsSecureString).Token"
after logging in to the correct tenant using "Connect-AzAccount --tenant <tenant-id>"''')
param AzureDevOpsSystemAccessToken string

@description('Azure DevOps Organisation Name. E.g. "myorg"')
param AzureDevOpsOrganisationName string

@description('Azure DevOps Project Name. E.g. "myproject"')
param AzureDevOpsProjectName string

@description('Azure DevOps Service Connection Name. E.g. "my-service-connection". Should contain only a-z, A-Z, 0-9, and . - _')
param AzureDevOpsServiceConnectionName string

@description('Azure resource location. E.g. "westeurope"')
param location string

@description('Gets or sets how the deployment script should be forced to execute even if the script resource has not changed. Do not change if you dont want the scripts to run again. Can be current time stamp or a GUID.')
param buildId string = 'firstrun'

@description('Optional Key-value pairs of tags to apply to the resources')
param tags object = {}

resource IssuerAndIdentifierIds 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ds-azdo-information'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    forceUpdateTag: buildId
    environmentVariables: [
      {
        name: 'SystemAccessToken'
        secureValue: AzureDevOpsSystemAccessToken
      }
    ]
    arguments: '-AzureDevOpsOrganisationName \\"${AzureDevOpsOrganisationName}\\" -AzureDevOpsProjectName \\"${AzureDevOpsProjectName}\\" -AzureDevOpsServiceConnectionName \\"${AzureDevOpsServiceConnectionName}\\"'
    scriptContent: '''
    param (
      [Parameter(Mandatory=$true)]
      [string] $AzureDevOpsOrganisationName,
      [Parameter(Mandatory=$true)]
      [string] $AzureDevOpsProjectName,
      [Parameter(Mandatory=$true)]
      [string] $AzureDevOpsServiceConnectionName
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$(${Env:SystemAccessToken})"))
    $header = @{
        Authorization = "Bearer ${Env:SystemAccessToken}"
    }

    # Get Azure DevOps Organisation ID
    $restApiAdoOrgInfo = "https://dev.azure.com/$AzureDevOpsOrganisationName/_apis/connectiondata?api-version=5.0-preview.1"
    $azureDevOpsOrganisationId = Invoke-RestMethod -Uri $restApiAdoOrgInfo -Headers $header -Method Get | Select-Object -ExpandProperty instanceId

    # Get Azure DevOps Project ID
    $restApiAdoProjectInfo = "https://dev.azure.com/$AzureDevOpsOrganisationName/_apis/projects/$($AzureDevOpsProjectName)?api-version=7.1-preview.4"
    $azureDevOpsProjectId = Invoke-RestMethod -Uri $restApiAdoProjectInfo -Headers $header -Method Get | Select-Object -ExpandProperty id

    # OIDC information needed for User Assigned Managed Identity
    $issuer = "https://vstoken.dev.azure.com/$azureDevOpsOrganisationId"
    $subjectIdentifier = "sc://$AzureDevOpsOrganisationName/$AzureDevOpsProjectName/$AzureDevOpsServiceConnectionName"

    $deploymentScriptOutputs = @{}
    $deploymentScriptOutputs["issuer"] = $issuer
    $deploymentScriptOutputs["subjectIdentifier"] = $subjectIdentifier
  '''
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: uaiName
  location: location
  tags: tags
  dependsOn: [
    IssuerAndIdentifierIds
  ]
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-07-31-preview' = {
  name: 'AzureDevOpsFederation-${replace(AzureDevOpsServiceConnectionName, '.', '-')}'
  parent: userAssignedIdentity
  properties: {
    issuer: IssuerAndIdentifierIds.properties.outputs.issuer
    subject: IssuerAndIdentifierIds.properties.outputs.subjectIdentifier
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource CreateServiceConnection 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ds-azdo-service-connection'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    forceUpdateTag: buildId
    environmentVariables: [
      {
        name: 'SystemAccessToken'
        secureValue: AzureDevOpsSystemAccessToken
      }
    ]
    arguments: '-AzureDevOpsOrganisationName \\"${AzureDevOpsOrganisationName}\\" -AzureDevOpsProjectName \\"${AzureDevOpsProjectName}\\" -AzureDevOpsServiceConnectionName \\"${AzureDevOpsServiceConnectionName}\\" -TenantId ${tenant().tenantId} -SubscriptionId ${subscription().subscriptionId} -SubscriptionName \\"${subscription().displayName}\\" -UserAssignedManagedIdentityClientId ${userAssignedIdentity.properties.clientId} -url ${environment().resourceManager}'
    scriptContent: '''
      param (
        [Parameter(Mandatory=$true)]
        [string] $AzureDevOpsOrganisationName,
        [Parameter(Mandatory=$true)]
        [string] $AzureDevOpsProjectName,
        [Parameter(Mandatory=$true)]
        [string] $AzureDevOpsServiceConnectionName,
        [Parameter(Mandatory=$true)]
        [string] $TenantId,
        [Parameter(Mandatory=$true)]
        [string] $SubscriptionId,
        [Parameter(Mandatory=$true)]
        [string] $SubscriptionName,
        [Parameter(Mandatory=$true)]
        [string] $UserAssignedManagedIdentityClientId,
        [Parameter(Mandatory=$true)]
        [string] $url
      )
      $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$(${Env:SystemAccessToken})"))
      $header = @{
        Authorization = "Bearer ${Env:SystemAccessToken}"
      }
      # Retrieve Azure DevOps Project ID
      $restApiAdoProjectInfo = "https://dev.azure.com/$AzureDevOpsOrganisationName/_apis/projects/$($AzureDevOpsProjectName)?api-version=7.1-preview.4"
      $azureDevOpsProjectId = Invoke-RestMethod -Uri $restApiAdoProjectInfo -Headers $header -Method Get | Select-Object -ExpandProperty id

      $body = @"
      {
          "authorization": {
              "parameters": {
                  "serviceprincipalid": "$UserAssignedManagedIdentityClientId",
                  "tenantid": "$TenantId"
              },
              "scheme": "WorkloadIdentityFederation"
          },
          "createdBy": {},
          "data": {
              "environment": "AzureCloud",
              "scopeLevel": "Subscription",
              "creationMode": "Manual",
              "subscriptionId": "$SubscriptionId",
              "subscriptionName": "$SubscriptionName"
          },
          "isShared": false,
          "isOutdated": false,
          "isReady": false,
          "name": "$AzureDevOpsServiceConnectionName",
          "owner": "library",
          "type": "AzureRM",
          "url": "$url",
          "description": "This service connection is backed by a user assigned managed identity $UserAssignedManagedIdentityClientId using identity federation. It does not have a password.",
          "serviceEndpointProjectReferences": [
              {
                  "description": "",
                  "name": "$AzureDevOpsServiceConnectionName",
                  "projectReference": {
                      "id": "$azureDevOpsProjectId",
                      "name": "$AzureDevOpsProjectName"
                  }
              }
          ]
      }
"@

  # Registering service connection
  $restApiEndpointUrl = "https://dev.azure.com/$AzureDevOpsOrganisationName/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
  $serviceConnection = Invoke-RestMethod -Uri $restApiEndpointUrl -Headers $header -Method Post -Body $body -ContentType "application/json"

  return $serviceConnection
'''
  }
  dependsOn: [
    federation
  ]
}

output uaiName string = userAssignedIdentity.name
output tenantId string = subscription().tenantId
output clientId string = userAssignedIdentity.properties.clientId
output subscriptionId string = subscription().subscriptionId
output subscriptionName string = subscription().displayName
