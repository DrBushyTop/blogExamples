# Make sure you're logged in with pwsh to the correct tenant / sub before running this script
param (
    [Parameter(Mandatory = $true)][string]$ResourceGroupName
)

$token = (Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" -AsSecureString).Token
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile "$PSScriptRoot/main.bicep" -TemplateParameterFile "$PSScriptRoot/serviceprincipal.bicepparam" -AzureDevOpsSystemAccessToken $token
Write-Host "You still need to assign permissions to the service principal in Azure"