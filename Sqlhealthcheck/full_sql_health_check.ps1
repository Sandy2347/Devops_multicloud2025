##


<#
.SYNOPSIS
    Full SQL Server Health Check Script
.DESCRIPTION
    This script checks:
    - Always On AG Health
    - SQL Backup status
    - Disk space on all drives
    - Generates HTML report (optional)
.NOTES
    Author: Your Name
#>

# Define SQL instance
$Instance = "localhost"
$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Check AG Health
Write-Output "`n[$Date] Checking Always On Availability Groups..."
try {
    $agStatus = Invoke-Sqlcmd -Query "
        SELECT ag.name AS AGName, ar.replica_server_name, ar.role_desc, ar.availability_mode_desc, ars.synchronization_health_desc
        FROM sys.availability_groups ag
        JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
        JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
        WHERE ars.is_local = 1" -ServerInstance $Instance

    $agStatus | Format-Table -AutoSize
} catch {
    Write-Warning "AG Health Check failed: $_"
}

# Check Backup Status (last 24 hours)
Write-Output "`n[$Date] Checking Backup Status (last 24 hours)..."
try {
    $backups = Invoke-Sqlcmd -Query "
        SELECT d.name AS DatabaseName, MAX(b.backup_finish_date) AS LastBackupTime, b.type AS BackupType
        FROM sys.databases d
        LEFT JOIN msdb.dbo.backupset b ON b.database_name = d.name
        WHERE d.name NOT IN ('tempdb') AND b.backup_finish_date > DATEADD(hour, -24, GETDATE())
        GROUP BY d.name, b.type" -ServerInstance $Instance

    $backups | Format-Table -AutoSize
} catch {
    Write-Warning "Backup Check failed: $_"
}

# Check Disk Space
Write-Output "`n[$Date] Checking Disk Space..."
try {
    Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, @{Name="Free(GB)";Expression={"{0:N2}" -f ($_.FreeSpace/1GB)}}, @{Name="Total(GB)";Expression={"{0:N2}" -f ($_.Size/1GB)}}
} catch {
    Write-Warning "Disk space check failed: $_"
}

Write-Output "`n[$Date] Health check completed."

# … after writing the HTML report to $ReportPath and populating $issues …

# Only send email if there are issues
if ($issues.Count -gt 0) {

    # Read in the HTML report
    $htmlBody = Get-Content -Path $ReportPath -Raw

    # Build a plain‑text summary for the email subject or fallback
    $summary = ($issues | ForEach-Object { "• $_" }) -join "<br/>"

    Send-MailMessage `
        -From       $from `
        -To         $to `
        -Subject    $subject `
        -Body       $htmlBody `
        -BodyAsHtml `
        -SmtpServer $smtpServer `
        # If your SMTP requires authentication, uncomment and fill in:
        # -Credential (Get-Credential) `
        # -UseSsl `
        # -Port 587
}

