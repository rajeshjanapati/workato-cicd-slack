# Input parameters
Param (
    [Parameter(mandatory = $true)][string]$accessToken, # To receive Workato token
    [Parameter(mandatory = $true)][string]$manifestId, # To receive manifest_ID    
    [Parameter(mandatory = $true)][string]$summary_file_name
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
$allSummaries_Log = ""

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

$allSummaries_Log += $manifestName_Log_Success + $manifestName_Log_Failed

cd ..

$currentdir = Get-Location
Write-Host "currentdir:$currentdir"

# Combine the current directory path with the file name
$filePath = Join-Path $currentdir $summary_file_name

# Write the combined summaries to the summary file
$allSummaries_Log | Out-File -FilePath $filePath -Append -Encoding UTF8
