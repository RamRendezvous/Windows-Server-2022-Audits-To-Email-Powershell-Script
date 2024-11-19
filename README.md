
# **File Monitoring and Email Notification Script**

This PowerShell script monitors file operations such as deletions and movements on a Windows system. It logs these events, stores them in a log file, and sends hourly summary emails to a designated recipient.

---

## **Features**
- Monitors file deletion and movement events in the Windows Security Event Log.
- Logs event details with timestamps in a central log file.
- Sends an hourly email summary of detected events.
- Automatically creates necessary log directories.

---

## **Prerequisites**
1. **PowerShell 5.0 or later**.
2. SMTP server credentials for sending email notifications.
3. Security Event Log audit policy configured to log file access events:
   - Enable auditing for "File System Access" in Group Policy.
   - Configure Audit Object Access:
     - Navigate to **`Local Security Policy > Advanced Audit Policy Configuration > Object Access > Audit File System`**.
     - Enable both Success and Failure auditing.

---

## **Installation**
1. Download the script to a directory on your system.
2. Open the script in a PowerShell editor.
3. Update the placeholders in the script with your configuration details (see **Configuration** section below).

---

## **Configuration**

### **SMTP Settings**
Update the following fields with your email server details:
```powershell
$smtpServer = ""          # SMTP server address
$smtpFrom = ""            # Sender's email address
$smtpTo = ""              # Recipient's email address
$username = ""            # SMTP username
$password = ""            # SMTP password
$subject = "Hourly File Operation Summary"  # Email subject
```

### **Log File Settings**
Ensure the log folder path is accessible or modify it as needed:
```powershell
$LogFolder = "C:\LOGS"                  # Folder for log files
$LogFile = "$LogFolder\FileAuditLog.txt"  # Master log file
$TempLogFile = "$LogFolder\HourlySummary.txt"  # Temporary log for hourly emails
```

---

## **Usage**

1. **Run the Script**  
   Open PowerShell as an administrator and execute the script:
   ```powershell
   .\FileMonitoringScript.ps1
   ```
   The script will run continuously, monitoring file operations and sending email summaries.

2. **Stop the Script**  
   To stop the script, use `Ctrl+C` in the PowerShell window where it is running.

---

## **How It Works**
1. **Event Monitoring**  
   The script uses `Get-WinEvent` to monitor Windows Security Event Log for event ID `4663` (indicating file access events).

2. **Logging**  
   Detected events are logged in real-time to `FileAuditLog.txt` and temporarily stored in `HourlySummary.txt` for email reporting.

3. **Email Notifications**  
   At hourly intervals, the script compiles a summary of events and sends it via email. After sending, the temporary log file is cleared.

4. **Error Handling**  
   Any errors during event monitoring or email sending are logged for troubleshooting.

---

## **Customization**
- Adjust the email frequency by modifying this line in the script:
   ```powershell
   $NextSummaryTime = (Get-Date).AddHours(1)
   ```
   Replace `1` with the desired interval in hours.

- Add more event filters or custom actions by editing the event-handling logic:
   ```powershell
   if ($AccessMask -eq "0x10000") { "Deleted" }
   elseif ($AccessMask -eq "0x20000") { "Moved" }
   ```

---

## **Known Limitations**
1. Requires elevated privileges to access Security Event Logs.
2. Only processes up to 10 events per iteration. Increase this limit by changing the `-MaxEvents` parameter:
   ```powershell
   $Events = Get-WinEvent -LogName Security -FilterXPath '*[System[EventID=4663]]' -MaxEvents 100
   ```

---

## **Support**
If you encounter issues or have suggestions for improvements, feel free to open an issue on the repository.

---

## **License**
This script is provided under the MIT License. Use it at your own risk and discretion.

---
