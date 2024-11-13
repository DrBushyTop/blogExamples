- data.bicep - SQL Server AAD only, Cstring, Storage. Outputs, KV
- appService.bicep - Identity setup, giving permissions
  - Log into App Service to show identity, env variables

```powershell
## Get relevant env variables
Get-ChildItem Env: | Where-Object { $_.Name -match "IDENTITY|MSI" } | ForEach-Object { "$($_.Name)=$($_.Value)" }

## Get token for App Service identity
$resourceURI = "https://vault.azure.net"
$tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token.Substring(0, 30)
Write-Output $accessToken

```

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
