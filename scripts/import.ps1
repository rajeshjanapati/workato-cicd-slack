# Input parameters
Param (
  [Parameter(mandatory = $true)][string]$accessToken, # To receive Workato token
  [Parameter(mandatory = $true)][string]$manifestName, # To receive manifest name
  [Parameter(mandatory = $true)][string]$action, # To receive type of action script shall perform
  [Parameter(mandatory = $true)][string]$folderId, # To receive folder ID
  [Parameter(mandatory = $true)][string]$summary_file_name
)

$headers = @{ 'Authorization' = "Bearer $accessToken" }

$manifestDirectory = "cicd"
Write-Host "manifestDirectory:$manifestDirectory"

# Initialize an empty string to store all environment summaries
$allSummaries_Log = ""

if ($action -eq "Create") {
  Set-Location $manifestDirectory
  $currentdir = Get-Location
  $manifestNameFolder = "$currentdir"
  Set-Location $manifestNameFolder


  # Check if the ZIP file exists in the current directory
  $zipFile = Get-ChildItem -Filter "$manifestName.zip"
  Write-Host "FileName:$zipFile"

  $allSummaries_Log += $manifestName

  if ($zipFile) {
    # Read the ZIP file as byte array
    $fileContent = [System.IO.File]::ReadAllBytes($zipFile)

    Write-Host "Found ZIP file: $zipFile"
    Write-Host "Start Import manifest for $manifestName"

    # Upload the ZIP file content to Workato
    Write-Host "Uploading ZIP file content to $uri..."
    $uri = "https://www.workato.com/api/packages/import/"+$folderId+"?restart_recipes=true"
    Write-Host "API:$uri"

    try {
      Invoke-RestMethod -Uri $uri -Method "POST" -Headers $headers -Body $fileContent -ContentType "application/zip"

      Write-Host "manifestName $manifestName"
    } catch {
      Write-Host "Error uploading ZIP file: $($_.Exception.Message)"
    }
  } else {
    Write-Host "No ZIP file found with the name $manifestName"
  }
}
elseif ($action -eq "ImportAll") {
  # Initialize an array to store proxy names
  $manifestName_Success = @()
  $manifestName_Failure = @()
  $manifestNameCountIn_Success = 0
  $manifestNameCountIn_Failed = 0

  Set-Location $manifestDirectory
  $currentdir = Get-Location
  $zipFiles = Get-ChildItem -Filter "*.zip"

  foreach ($zipFile in $zipFiles) {
    $fileContent = [System.IO.File]::ReadAllBytes($zipFile)

    Write-Host "Found ZIP file: $zipFile"
    # File path
    $filePath = $zipFile
    
    # Extract the base name without extension
    $baseNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    
    # Output the result
    Write-Host "Base name without extension: $baseNameWithoutExtension"

    $manifestName_Success += $baseNameWithoutExtension

    # Upload the ZIP file content to Workato
    $uri = "https://www.workato.com/api/packages/import/"+$folderId+"?restart_recipes=true"
    Write-Host "API:$uri"

    try {
      Invoke-RestMethod -Uri $uri -Method "POST" -Headers $headers -Body $fileContent -ContentType "application/zip"
      Write-Host "manifestName $($zipFile.BaseName)"
    } catch {
      $manifestName_Failure += $baseNameWithoutExtension
      Write-Host "Error uploading ZIP file $($zipFile.BaseName): $($_.Exception.Message)"
    }
  }

  $manifestNameList_Success =  $($manifestName_Success -join ', ')
  $manifestNameList_Failed =  $($manifestName_Failure -join ', ')

  $manifestNameCountIn_Success = $manifestName_Success.Count
  $manifestNameCountIn_Failed = $manifestName_Failure.Count

  $manifestName_Log_Success = ("manifest Recipes Imported Successfully to Workato: Count - $manifestNameCountIn_Success, Manifest Names - $manifestNameList_Success`r`n")
  $manifestName_Log_Failed = ("manifest Recipes Import Failed: Count - $manifestNameCountIn_Failed, Manifest Names - $manifestNameList_Failed`r`n")

  $allSummaries_Log += $manifestName_Log_Success + $manifestName_Log_Failed

}

else{
  Write-Host "Please atleast one action to perform...!"
}

# $manifestDirectory = "cicd"
# Set-Location $manifestDirectory

# Combine the current directory path with the file name
$filePath = Join-Path -Path $PWD -ChildPath $summary_file_name

# Write the combined summaries to the summary file
$allSummaries_Log | Out-File -FilePath $filePath -Append -Encoding UTF8

