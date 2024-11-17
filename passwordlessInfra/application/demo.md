- show appservice in portal, identity tab
- appService.bicep - Identity setup, giving permissions, env variables
- data.bicep - SQL Server AAD only, Cstring, Storage. Outputs, KV

- Log into App Service to show identity, env variables

```powershell
## Get relevant env variables
Get-ChildItem Env: | Where-Object { $_.Name -match "IDENTITY|MSI" } | ForEach-Object {
    $maskedValue = if ($_.Name -match "HEADER|SECRET") {
        "$($_.Value.Substring(0, 3))***$($_.Value.Substring($_.Value.Length - 3, 3))"
    } else {
        $_.Value
    }
    "$($_.Name)=$maskedValue"
}
# IDENTITY_HEADER is used to help mitigate server-side request forgery (SSRF) attacks.

## Get token for App Service identity
$resourceURI = "https://vault.azure.net"
$tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token.Substring(0, 30)
Write-Output $accessToken

```

- show portal managed identity menu

- Permissions to SQL

```sql
CREATE USER [phcloudbrew-appservice] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [phcloudbrew-appservice];

-- List users
SELECT name, type_desc, authentication_type_desc FROM sys.database_principals WHERE name = 'phcloudbrew-appservice';

-- List roles for user
SELECT name, type_desc FROM sys.database_principals WHERE type = 'R'
AND principal_id IN
	(SELECT role_principal_id FROM sys.database_role_members WHERE member_principal_id = USER_ID('phcloudbrew-appservice'));

-- Delete user
DROP USER [phcloudbrew-appservice];
GO
```

## Extra

- vmStuff.bicep - VM tagging, log into VM to show metadata and auth endpoints, tags

```bash
## Get metadata from VM
curl -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -s | jq

## Get Tags
curl -H "Metadata:true" "http://169.254.169.254/metadata/instance/compute/tagsList?api-version=2021-02-01" -s | jq

##  Get identity details
curl -H "Metadata:true" "http://169.254.169.254/metadata/instance/compute/identity?api-version=2021-02-01" -s | jq

## Get token for VM identity
curl -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://management.azure.com/" -s | cut -c -30
```

- Show DefaultAzureCredential from code, and how it works with MSI
