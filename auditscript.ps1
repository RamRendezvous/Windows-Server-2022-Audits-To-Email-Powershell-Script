# Email Configuration
$smtpServer = ""          # SMTP server
$smtpFrom = ""                     # Sender's email
$smtpTo = ""                      # Recipient's email
$username = ""                     # SMTP username
$password = ""                 # SMTP password
$subject = "Hourly File Operation Summary"

# Convert SMTP password to a secure string
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securePassword

# Log File Configuration
$LogFolder = "C:\LOGS"
$LogFile = "$LogFolder\FileAuditLog.txt"
$TempLogFile = "$LogFolder\HourlySummary.txt"

# Ensure Log Folder Exists
if (!(Test-Path -Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

# Log Function
function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Add-Content -Path $TempLogFile -Value $LogEntry
    Write-Output $LogEntry  # Real-time console output
}

# Function to Send Consolidated Email
function Send-ConsolidatedEmail {
    if (Test-Path $TempLogFile) {
        $emailBody = Get-Content $TempLogFile -Raw
        try {
            Send-MailMessage -From $smtpFrom -To $smtpTo -Subject $subject -Body $emailBody -SmtpServer $smtpServer -Credential $credential -Port 587 -UseSsl
            Write-Log "Hourly summary email sent successfully."
            Remove-Item $TempLogFile  # Clear the temporary log file
        } catch {
            Write-Log "Failed to send hourly summary email. Error: $_"
        }
    } else {
        Write-Log "No events to include in the hourly summary email."
    }
}

# Initialize Script
Write-Log "Script started. Monitoring events for file deletions and movements."

# Continuous Monitoring for File Deletion and Movement
try {
    $NextSummaryTime = (Get-Date).AddHours(1)
    while ($true) {
        # Monitor Event Log for File Deletion/Movement (Event ID: 4663)
        $Events = Get-WinEvent -LogName Security -FilterXPath '*[System[EventID=4663]]' -MaxEvents 10
        foreach ($Event in $Events) {
            $Time = $Event.TimeCreated
            $User = $Event.Properties[1].Value
            $File = $Event.Properties[6].Value
            $AccessMask = $Event.Properties[4].Value

            # Detect Deletion or Movement
            $Action = if ($AccessMask -eq "0x10000") { "Deleted" } elseif ($AccessMask -eq "0x20000") { "Moved" } else { "Unknown" }

            # Log Event
            $Message = @"
File Operation Detected:
- User: $User
- File/Folder: $File
- Action: $Action
- Time: $Time
"@
            Write-Log $Message
        }

        # Send hourly summary if it's time
        if ((Get-Date) -ge $NextSummaryTime) {
            Write-Log "Sending hourly summary email."
            Send-ConsolidatedEmail
            $NextSummaryTime = (Get-Date).AddHours(1)  # Schedule next summary
        }

        # Sleep for 5 seconds before checking for new events
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Log "An error occurred while monitoring events. Error: $_"
}
