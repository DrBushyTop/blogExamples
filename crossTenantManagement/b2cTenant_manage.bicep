extension microsoftGraphV1

targetScope = 'subscription' // Needs a subscription link in b2c, see https://www.huuhka.net/monitoring-setup-for-azure-ad-b2c/

// Defaults only for example purposes
param memberPrincipalIds string[] = [
  '195e2a88-306d-4a31-ab9d-0ae3371fc9be'
]

resource groupToManage 'Microsoft.Graph/groups@v1.0' = {
  uniqueName: 'b2cUsersAutomated'
  displayName: 'B2C Users Automated'
  description: 'Group that will be managed by the B2C Tenant Automator'
  mailEnabled: false
  mailNickname: 'b2cUsersAutomated'
  securityEnabled: true
  owners: [
    deployer().objectId
  ]
  members: memberPrincipalIds
}
