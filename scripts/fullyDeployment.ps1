#Export

# Input parameters
Param (
    [Parameter(mandatory = $true)][string]$accessToken, # To receive Workato token
    [Parameter(mandatory = $true)][string]$manifestId, # To receive manifest_ID    
    [Parameter(mandatory = $true)][string]$summary_file_name,
    [Parameter(mandatory = $true)][string]$prodToken, # To receive Workato token
    [Parameter(mandatory = $true)][string]$manifestName, # To receive manifest name
    [Parameter(mandatory = $true)][string]$action, # To receive type of action script shall perform
    [Parameter(mandatory = $true)][string]$folderId, # To receive folder ID
)

$CurrentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch is: $CurrentBranch"

$headers = @{ Authorization = "Bearer $accessToken" }

# create cicd folder if not exists
$cicdPath = "cicd"
if (!(Test-Path -PathType Container $cicdPath)) {
    mkdir $cicdPath
    cd $cicdPath
    Write-Host "Inside if: Created and moved to $cicdPath"
} else {
    cd $cicdPath
}

# Initialize an empty string to store all environment summaries
$allSummaries_Log_Export = ""

# Initialize an array to store proxy names
$manifestName_Success = @()
$manifestName_Failure = @()
$manifestNameCountIn_Success = 0
$manifestNameCountIn_Failed = 0

# Initial API request to get the ID
$idPath = "https://www.workato.com/api/packages/export/$manifestId"

try {
    $idResponse = Invoke-RestMethod -Uri $idPath -Method 'POST' -Headers $headers -ContentType "application/json" -ErrorAction Stop -TimeoutSec 60

    # Check if the response content is not empty
    if ($idResponse) {
        # Extract the "id" value
        $idValue = $idResponse.id

        # Print the result
        Write-Host "ID Value: $idValue"

        # Make subsequent API requests until download_url is not null
        $downloadURL = $null
        do {
            $downloadURLpath = "https://www.workato.com/api/packages/$idValue"
            Write-Host "downloadURLpath: $downloadURLpath"

            $downloadURLresponse = Invoke-RestMethod $downloadURLpath -Method 'GET' -Headers $headers

            if ($downloadURLresponse) {
                $currentdir = Get-Location
                $downloadURL = $downloadURLresponse.download_url

                if ($downloadURL -ne $null -and $downloadURL -ne "null") {
                    # Extract file name from the URL without query parameters
                    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($downloadURL)

                    # Set the path where you want to save the file (inside the cicd folder)
                    $savePath = Join-Path $currentdir "$fileName.zip"

                    # Check if the file already exists, and delete it if it does
                    if (Test-Path $savePath) {
                        Remove-Item $savePath -Force
                        Write-Host "Deleted existing file: $savePath"
                    }

                    try {
                        $manifestName_Success += $fileName
                        # Download the file
                        Invoke-WebRequest -Uri $downloadURL -OutFile $savePath

                        Write-Host "File downloaded successfully!"
                    }
                    catch {
                        $manifestName_Failure += $fileName
                        Write-Host "API Request Failed. Error: $_"
                        Write-Host "Response Content: $_.Exception.Response.Content"
                    }
                }
            } else {
                Write-Host "API Request Successful but response content is empty."
            }

            # Delay before making the next request (optional)
            Start-Sleep -Seconds 5
        } while ($downloadURL -eq $null -or $downloadURL -eq "null")
    } else {
        Write-Host "API Request Successful but response content is empty."
    }
}
catch {
    Write-Host "API Request Failed. Error: $_"
    Write-Host "Response Content: $_.Exception.Response.Content"
}

$manifestNameList_Success =  $($manifestName_Success -join ', ')
$manifestNameList_Failed =  $($manifestName_Failure -join ', ')

$manifestNameCountIn_Success = $manifestName_Success.Count
$manifestNameCountIn_Failed = $manifestName_Failure.Count

$manifestName_Log_Success = ("manifest Recipe Exported Successfully to GitHub: Count - $manifestNameCountIn_Success, Manifest Names - $manifestNameList_Success`r`n")
$manifestName_Log_Failed = ("manifest Recipe Export Failed: Count - $manifestNameCountIn_Failed, Manifest Names - $manifestNameList_Failed`r`n")

$allSummaries_Log_Export += $manifestName_Log_Success + $manifestName_Log_Failed

cd ..

$currentdir = Get-Location
Write-Host "currentdir:$currentdir"

# Combine the current directory path with the file name
#$filePath = Join-Path $currentdir $summary_file_name

# Write the combined summaries to the summary file
#$allSummaries_Log | Out-File -FilePath $filePath -Append -Encoding UTF8



$headers = @{ 'Authorization' = "Bearer $prodToken" }

$manifestDirectory = "cicd"
Write-Host "manifestDirectory:$manifestDirectory"

# Initialize an empty string to store all environment summaries
$allSummaries_Log_Import = ""

if ($action -eq "Create") {
  Set-Location $manifestDirectory
  $currentdir = Get-Location
  $manifestNameFolder = "$currentdir"
  Set-Location $manifestNameFolder


  # Check if the ZIP file exists in the current directory
  $zipFile = Get-ChildItem -Filter "$manifestName.zip"
  Write-Host "FileName:$zipFile"

  $allSummaries_Log_Import += $manifestName

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

  $allSummaries_Log_Import += $manifestName_Log_Success + $manifestName_Log_Failed

}

else{
  Write-Host "Please atleast one action to perform...!"
}

# $manifestDirectory = "cicd"
# Set-Location $manifestDirectory

$allSummaries_Log = "Export Summary:`r`n"
$allSummaries_Log += $allSummaries_Log_Export + "`r`n"

$allSummaries_Log += "Import Summary:`r`n"
$allSummaries_Log += $allSummaries_Log_Import + "`r`n"

# Combine the current directory path with the file name
$filePath = Join-Path -Path $PWD -ChildPath $summary_file_name

# Write the combined summaries to the summary file
$allSummaries_Log | Out-File -FilePath $filePath -Append -Encoding UTF8
