using 'appRegistration.bicep'

param appRegConf = {
  name: 'bicepgraphdemo34242222'
  identifierUri: 'https://bicepgraphdemo34242222.huuhka.net'
}
param appInfraInfo = {
  backendAppServiceName: 'someAppServiceName25322'
  callingApplicationPrincipalId: '1c0b2359-0368-45e6-b88f-edc9f6ddc785' // principal ID of a service principal
  frontendSWAAddress: 'rough-plain-02deb2202.5.azurestaticapps.net'
}
