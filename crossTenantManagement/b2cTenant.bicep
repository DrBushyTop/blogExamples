extension microsoftGraphV1

targetScope = 'subscription' // Needs a subscription link in b2c, see https://www.huuhka.net/monitoring-setup-for-azure-ad-b2c/
// Might be better to do this via CLI instead. See https://www.jannemattila.com/azure/2024/12/31/mi-access-across-tenants.html

param homeTenantAppRegClientID string

resource b2cAutomator 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: homeTenantAppRegClientID
  appDescription: 'Home tenant will get tokens for this service principal. It will manage the B2C tenant group in this case'
  displayName: 'B2C Tenant Automator Service Principal'
}

resource groupToManage 'Microsoft.Graph/groups@v1.0' = {
  uniqueName: 'b2cUsersAutomated'
  displayName: 'B2C Users Automated'
  description: 'Group that will be managed by the B2C Tenant Automator'
  mailEnabled: false
  mailNickname: 'b2cUsersAutomated'
  securityEnabled: true
  owners: [
    b2cAutomator.id
  ]
}

output groupUniqueName string = groupToManage.uniqueName
output groupId string = groupToManage.id
output groupDisplayName string = groupToManage.displayName
// Or just output the whole group
