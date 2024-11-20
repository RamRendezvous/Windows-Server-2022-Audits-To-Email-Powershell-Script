# Email Configuration
$smtpServer = ""          # SMTP server
$smtpFrom = ""                     # Sender's email
$smtpTo = ""                      # Recipient's email
$username = ""                     # SMTP username

# Securely prompt for the SMTP password
$password = Read-Host -AsSecureString "Enter SMTP Password"  # Securely input SMTP password
$subject = "File Operation Summary"

# Create credential object
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

# Log File Configuration
$LogFolder = "C:\LOGS"
$LogFile = Join-Path $LogFolder "FileAuditLog.txt"
$TempLogFile = Join-Path $LogFolder "SummaryLog.txt"

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

# Function to Scan Past 7 Days for Relevant Events with a 30-Second Time Limit
function Scan-PastEvents {
    Write-Log "Scanning past logs for file deletions or movements in the last 7 days (limited to 30 seconds)..."
    $SevenDaysAgo = (Get-Date).AddDays(-7)
    $EndTime = (Get-Date).AddSeconds(30)  # Set the time limit to 30 seconds

    try {
        # Filter events by time range and event ID for efficiency
        $FilterHashTable = @{
            LogName   = 'Security'
            Id        = 4663
            StartTime = $SevenDaysAgo
            EndTime   = Get-Date
        }
        $Events = Get-WinEvent -FilterHashtable $FilterHashTable -ErrorAction Stop

        foreach ($Event in $Events) {
            # Check if the time limit has been reached
            if ((Get-Date) -ge $EndTime) {
                Write-Log "Time limit of 30 seconds reached during past event scanning."
                break
            }

            $Time = $Event.TimeCreated
            $User = $Event.Properties[1].Value
            $File = $Event.Properties[6].Value
            $AccessMask = $Event.Properties[4].Value

            # Detect Deletion or Movement
            $Action = switch ($AccessMask) {
                "0x10000" { "Deleted" }
                "0x20000" { "Moved" }
                default { $null }
            }

            if ($Action) {
                # Log Event
                $Message = @"
Past File Operation Detected:
- User: $User
- File/Folder: $File
- Action: $Action
- Time: $Time
"@
                Write-Log $Message
            }
        }
    } catch {
        Write-Log "An error occurred during past event scanning. Error: $_"
    }
}

# Function to Send Consolidated Email
function Send-ConsolidatedEmail {
    if (Test-Path $TempLogFile) {
        $emailBody = Get-Content $TempLogFile -Raw
        try {
            Send-MailMessage -From $smtpFrom -To $smtpTo -Subject $subject -Body $emailBody -SmtpServer $smtpServer -Credential $credential -Port 587 -UseSsl -ErrorAction Stop
            Write-Log "Summary email sent successfully."
            Remove-Item $TempLogFile -Force  # Clear the temporary log file
        } catch {
            Write-Log "Failed to send summary email. Error: $_"
        }
    } else {
        Write-Log "No events to include in the summary email."
    }
}

# Initialize Script
Write-Log "Script started. Monitoring events for file deletions and movements."

# Scan Past 7 Days Before Starting (with 30-second limit)
Scan-PastEvents

# Continuous Monitoring for File Deletion and Movement
try {
    $NextSummaryTime = (Get-Date).AddMinutes(45)  # Adjust interval here as needed
    while ($true) {
        # Monitor Event Log for File Deletion/Movement (Event ID: 4663)
        $RecentEvents = Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4663
            StartTime = (Get-Date).AddSeconds(-10)
            EndTime   = Get-Date
        } -ErrorAction SilentlyContinue

        foreach ($Event in $RecentEvents) {
            $Time = $Event.TimeCreated
            $User = $Event.Properties[1].Value
            $File = $Event.Properties[6].Value
            $AccessMask = $Event.Properties[4].Value

            # Detect Deletion or Movement
            $Action = switch ($AccessMask) {
                "0x10000" { "Deleted" }
                "0x20000" { "Moved" }
                default { $null }
            }

            if ($Action) {
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
        }

        # Send summary email if it's time
        if ((Get-Date) -ge $NextSummaryTime) {
            Write-Log "Sending summary email."
            Send-ConsolidatedEmail
            $NextSummaryTime = (Get-Date).AddMinutes(45)  # Reset the interval
        }

        # Sleep for 5 seconds before checking for new events
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Log "An error occurred while monitoring events. Error: $_"
}
