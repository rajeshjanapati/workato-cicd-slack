# Function for sending notifications
function Post-MessagesToTeams {
    param (
        $title, $summary, $workflowName, $runId, $runNumber, $executionTimestamp, $triggeredByName, $eventType, $gitBranch, $jobStatus, $artifactLink, $teamsWebhookURL, $messageColor, $themeColor
    )
    
    # Determine the notification parameters based on the job status
    if ($jobStatus -eq "success") {
        $TITLE = "GitHub Notification - Job completed successfully"
        $SUMMARY = "GitHub Notification from Apigee Export Management completed successfully"
        $MESSAGE_COLOR = "green"
        $THEME_COLOR = "008000"
    } else {
        $TITLE = "GitHub Notification - Job failed to complete due to errors"
        $SUMMARY = "GitHub Notification from Apigee Export Management has failed due to some errors"
        $MESSAGE_COLOR = "red"
        $THEME_COLOR = "D60000"
    }
    Write-Host "EVENT_TYPE:$EVENT_TYPE"
    # Check the event type and set the eventType variable
    if ($EVENT_TYPE -eq "workflow_dispatch") {
        Write-Host "This workflow was triggered manually."
        $eventType = "Manual Run"
        # Add your manual run-specific logic here
    } elseif ($EVENT_TYPE -eq "schedule") {
        Write-Host "This workflow was triggered by a schedule."
        $eventType = "Scheduled Run"
        # Add your scheduled run-specific logic here
    } else {
        Write-Host "Unknown event: $EVENT_TYPE"
        $eventType = "Unknown"
        # Handle other event types as needed
    }
    
    # Create the JSON payload for the notification
    $JSON = @{
        title = $TITLE
        summary = $SUMMARY
        text = "Workflow Name: <b> $workflowName </b><br>Run ID: $runId<br>Run Number: $runNumber<br>Timestamp: $executionTimestamp<br>Triggered by: <b> $triggeredByName </b><br>EventType: $eventType <br>Branch: $gitBranch<br> Status: <font color='$MESSAGE_COLOR'><b>$jobStatus</b></font><br>Artifact Link: $artifactLink"
        themeColor = $THEME_COLOR
    } | ConvertTo-Json

    try {
        # Send the notification to Teams
        $response = Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method POST -Headers @{"Content-Type"="application/json"} -Body $JSON
        return $response

    } catch {
        Write-Output "Failed to send notification: $_"
        return $null  # Indicates failure
    }
    }
