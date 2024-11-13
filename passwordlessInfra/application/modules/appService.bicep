param appServiceName string
param appServicePlanName string
param location string

param keyVaultName string
param appInsightsCstringKeyVaultRef string
param sqlConnectionStringKeyVaultRef string

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    capacity: 1
    name: 'S1'
    tier: 'Standard'
  }
  properties: {}
}

resource api 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  kind: 'app'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      http20Enabled: true
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource api_appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'appsettings'
  parent: api
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsCstringKeyVaultRef
    APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
    DiagnosticServices_EXTENSION_VERSION: '~3'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    SnapshotDebugger_EXTENSION_VERSION: '~2'
    Sql__ConnectionString: sqlConnectionStringKeyVaultRef
    ASPNETCORE_ENVIRONMENT: 'AzureProduction'
    WEBSITE_ADD_SITENAME_BINDINGS_IN_APPHOST_CONFIG: '1'
    WEBSITE_RUN_FROM_PACKAGE: '1'
    #disable-next-line no-hardcoded-env-urls // NOT POSSIBLE TO USE environment() IN THIS URL
    AzureAd__Instance: 'https://login.microsoftonline.com/'
    AzureAd__Domain: 'huuhka.net'
    AzureAd__TenantId: subscription().tenantId
    // AzureAd__ClientId: solutionAppRegClientId
    // AzureAd__Audience: solutionAppRegClientId
    // SwaggerUi__ClientId: solutionAppRegClientId
    #disable-next-line no-hardcoded-env-urls // NOT ACTUALL HARDCODED URL
    Logging__LogLevel__Default: 'Warning'
    Logging__LogLevel__Microsoft: 'Warning'
    Microsoft__Hosting__Lifetime: 'Warning'
  }
}

// Could just set the permission on the specific secret too if we wanted to be even more secure
module kvPermissions 'keyvaultUser.bicep' = {
  name: 'kvPermissions'
  params: {
    keyVaultName: keyVaultName
    identityPrincipalId: api.identity.principalId
    principalType: 'ServicePrincipal'
    role: 'Key Vault Secrets User'
  }
}

output appServiceName string = api.name
output appServiceId string = api.id
output appServicePlanName string = plan.name
output appServicePlanId string = plan.id
