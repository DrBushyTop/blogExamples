# PowerShell Script: deployments.ps1

## USAGE: Dot source the file '. ./deployments.ps1' to load the functions into the current session
## Call functions from powershell with e.g 'ProjectName-Login' or 'ProjectName-Up'

# Hardcoded variables
$tenantId = "YOUR_TENANT_ID"
$subscriptionId = "YOUR_SUBSCRIPTION_ID"
$resourceGroupName = "YOUR_DEV_RESOURCE_GROUP_NAME" ## I often have this created before hand, so the script does not create it
$gitRootDir = git rev-parse --show-toplevel
$backendProjectRootPath = "$gitRootDir/My.BackendProject"
$backendProjectPath = "$backendProjectRootPath/My.BackendProject.csproj"
$functionProjectRootPath = "$gitRootDir/My.FunctionProject"
$functionProjectPath = "$functionProjectRootPath/My.FunctionProject.csproj"

function GeneratePassword {
  param(
    [ValidateRange(12, 256)]
    [int]
    $length = 25
  )

  $symbols = '!@#$%^&*'.ToCharArray()
  $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $symbols

  do {
    $password = -join (0..$length | ForEach-Object { $characterList | Get-Random })
    [int]$hasLowerChar = $password -cmatch '[a-z]'
    [int]$hasUpperChar = $password -cmatch '[A-Z]'
    [int]$hasDigit = $password -match '[0-9]'
    [int]$hasSymbol = $password.IndexOfAny($symbols) -ne -1

  }
  until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol) -ge 3)

  $password
}

function ProjectName-Update {
  az upgrade -y
  az bicep upgrade
  Write-Output "Installing SqlServer module... You might already have it installed, so this might fail."
  Install-Module -Name SqlServer -Force -AcceptLicense
}

function ProjectName-Login {
  az login --tenant $tenantId
  az account set --subscription $subscriptionId
}

function ProjectName-Infra {
  param (
    [string]$environment = "Development"
  )

  Write-Output "Creating development directory if it does not exist..."
  mkdir $gitRootDir/.development

  Write-Output "Getting your public IP address to allow SQL Server access..."
  $ipAddress = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" | Select-Object -ExpandProperty ip
  Write-Output "Your external IP address is: $ipAddress"

  Write-Output "Deploying infrastructure..."
  az deployment group create `
    -g $resourceGroupName `
    --template-file $gitRootDir/Deployment/Bicep/main.bicep `
    --parameters $gitRootDir/Deployment/Bicep/arm.$($environment).params.jsonc `
    --parameters sqlAdministratorLoginPassword=$(GeneratePassword) `
    --parameters sqlServerUserIpAddress=$ipAddress `
    --query properties.outputs | Tee-Object -FilePath $gitRootDir/.development/envvars

  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }

  ProjectName-Set-SqlWebAppPermissions-All
}

function ProjectName-GetInfraOutputs {
  mkdir $gitRootDir/.development

  az deployment group show `
    -g $resourceGroupName `
    --name main `
    --query properties.outputs | Tee-Object -FilePath $gitRootDir/.development/envvars
}

function ProjectName-Deploy {
  ProjectName-Deploy-Backend
  ProjectName-Deploy-Function
}

function ProjectName-Deploy-Backend {
  $envVars = Get-Content .development/envvars | ConvertFrom-Json
  $funcName = $envVars.BackendName.value

  $databaseName = $envVars.backendDatabaseName.value
  $sqlServerFqdn = $envVars.sqlServerFQDN.value

  Write-Output "Generating and Running Migration Script..."
  $scriptPath = ProjectName-Generate-Migration-Script-Backend
  $access_token = az account get-access-token --scope "https://database.windows.net/.default" --query accessToken -o tsv
  Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -AccessToken $access_token -Database $databaseName -InputFile $scriptPath
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }

  Write-Output "Building backend..."
  dotnet publish $backendProjectPath --configuration Release --output "$gitRootDir/.development/backend_publish"
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }
  Compress-Archive -Path "$gitRootDir/.development/backend_publish/*" -DestinationPath "$gitRootDir/.development/backend_publish.zip" -Force
  Write-Output "Deploying backend..."
  az webapp deployment source config-zip `
    -g $resourceGroupName `
    -n $funcName `
    --src $gitRootDir/.development/backend_publish.zip
}

function ProjectName-Deploy-Function {
  $envVars = Get-Content .development/envvars | ConvertFrom-Json
  $funcName = $envVars.FunctionName.value
  $databaseName = $envVars.functionDatabaseName.value
  $sqlServerFqdn = $envVars.sqlServerFQDN.value

  Write-Output "Generating and Running Migration Script..."
  $scriptPath = ProjectName-Generate-Migration-Script-Function
  $access_token = az account get-access-token --scope "https://database.windows.net/.default" --query accessToken -o tsv
  Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -AccessToken $access_token -Database $databaseName -InputFile $scriptPath
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }
  Write-Output "Deploying function..."
  Set-Location $functionProjectRootPath
  func azure functionapp publish $funcName --dotnet-isolated
  Set-Location $gitRootDir

  ### The az functionapp deployment does not seem to work correctly (missing runtime-version after zipping), so we are using the func cli instead
  # dotnet publish $functionProjectPath --configuration Release --output "$gitRootDir/.development/function_publish"
  # if (-not $? -or $LASTEXITCODE -ne 0) {
  #   throw "The command failed to execute successfully."
  # }
  # Compress-Archive -Path "$gitRootDir/.development/function_publish/*" -DestinationPath "$gitRootDir/.development/function_publish.zip" -Force
  # az functionapp deployment source config-zip `
  #   -g $resourceGroupName `
  #   -n $funcName `
  #   --src $gitRootDir/.development/function_publish.zip
  # if (-not $? -or $LASTEXITCODE -ne 0) {
  #   throw "The command failed to execute successfully."
  # }
}

function ProjectName-Generate-Migration-Script-Function {
  $scriptPath = "$gitRootDir/.development/migration_script_function.sql"

  dotnet ef migrations script -i -o $scriptPath -s "$functionProjectPath" -p "$gitRootDir/My.FuncSQL/My.FuncSQL.csproj"  | Out-Host
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }
  # Return the script path
  return $scriptPath
}

function ProjectName-Generate-Migration-Script-Backend {
  $scriptPath = "$gitRootDir/.development/migration_script_backend.sql"

  dotnet ef migrations script -i -o $scriptPath -s "$backendProjectPath" -p "$gitRootDir/My.BackendSql/My.BackendSql.csproj"  | Out-Host
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "The command failed to execute successfully."
  }
  # Return the script path
  return $scriptPath
}

function ProjectName-Up {
  param (
    [string]$environment = "Development"
  )
  $ErrorActionPreference = "Stop"
  ProjectName-Infra -environment $environment
  ProjectName-Deploy
}

function ProjectName-Set-SqlWebAppPermissions-All {
  $envVars = Get-Content .development/envvars | ConvertFrom-Json
  $sqlServerFqdn = $envVars.sqlServerFQDN.value
  $functionName = $envVars.functionName.value
  $functionDatabaseName = $envVars.functionDatabaseName.value
  $backendWebAppName = $envVars.BackendName.value
  $backendDatabaseName = $envVars.backendDatabaseName.value

  Write-Output "Setting SQL permissions for web apps..."
  Set-SqlWebAppPermissions -webAppName $backendWebAppName -sqlServerFqdn $sqlServerFqdn -databaseName $backendDatabaseName
  Set-SqlWebAppPermissions -webAppName $functionName -sqlServerFqdn $sqlServerFqdn -databaseName $functionDatabaseName
}

function Set-SqlWebAppPermissions {
  param (
    [string]$webAppName,
    [string]$sqlServerFqdn,
    [string]$databaseName
  )

  # Check if the user already exists
  ## TODO: Does not work if you delete a single database and try to recreate it. The user is still there.
  $access_token = az account get-access-token --scope "https://database.windows.net/.default" --query accessToken -o tsv
  $userExistsQuery = "SELECT COUNT( * ) FROM sys.database_principals WHERE name = '$webAppName'"
  $userExists = Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -AccessToken $access_token -Database $databaseName -Query $userExistsQuery -QueryTimeout 120

  if ($userExists -eq 0) {
    Write-Output "Creating user $webAppName..."
    # Create Managed Identity user and grant permissions
    $query = "CREATE USER [$webAppName] FROM EXTERNAL PROVIDER; "
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -AccessToken $access_token -Database $databaseName -Query $query -QueryTimeout 120
  }
  else {
    Write-Output "User $webAppName already exists."
  }

  Write-Output "Granting permissions to $webAppName..."
  $query = "EXEC sp_addrolemember 'db_datareader', '$webAppName'; "
  $query = $query + "EXEC sp_addrolemember 'db_datawriter', '$webAppName'; "
  Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -AccessToken $access_token -Database $databaseName -Query $query -QueryTimeout 120
}
