<#
.SYNOPSIS
    Full SQL Server Health Check Script with HTML report and email alerts.
.DESCRIPTION
    Checks:
      - Always On AG Health
      - SQL Backup status (last 24 hrs)
      - Disk space on all drives
    Generates an HTML report and emails it (as HTML) if any issues are detected.
.PARAMETER Instance
    SQL Server instance name (default: localhost)
.PARAMETER ReportPath
    Full path where the HTML report will be saved
.PARAMETER smtpServer
    SMTP server for sending alerts
.PARAMETER from
    Email From address
.PARAMETER to
    Email To address
.PARAMETER subject
    Email subject
.PARAMETER backupThresholdHours
    Hours since last backup before flagging
.PARAMETER diskFreeThresholdPercent
    Minimum free disk percentage before flagging
#>

param(
    [string]$Instance               = "localhost",
    [string]$ReportPath             = "$env:TEMP\Full_SQL_Health_Report.html",
    [string]$smtpServer             = "smtp.yourdomain.com",
    [string]$from                   = "sql-monitor@yourdomain.com",
    [string]$to                     = "dba-team@yourdomain.com",
    [string]$subject                = "SQL Server Full Health Report",
    [int]   $backupThresholdHours   = 24,
    [int]   $diskFreeThresholdPercent = 15
)

# Load SMO if needed for more advanced queries (optional)
# Add-Type -AssemblyName "Microsoft.SqlServer.Smo"

$issues = @()
$html  = @()
$html += "<html><body><h1>SQL Server Health Check - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</h1>"

#
# 1. Always On AG Health
#
$html += "<h2>Always On AG Health</h2><table border='1' cellpadding='5'><tr><th>AG</th><th>Replica</th><th>Role</th><th>Health</th></tr>"
try {
    $agRows = Invoke-Sqlcmd -ServerInstance $Instance -Query @"
        SELECT ag.name AS AGName,
               ar.replica_server_name AS Replica,
               ars.role_desc AS Role,
               ars.synchronization_health_desc AS Health
        FROM sys.availability_groups ag
        JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
        JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
        WHERE ars.is_local = 1
"@
    foreach ($r in $agRows) {
        $color = if ($r.Health -eq "HEALTHY") { "green" } else { "red"; $issues += "AG $($r.AGName) on $Instance: $($r.Health)" }
        $html += "<tr><td>$($r.AGName)</td><td>$($r.Replica)</td><td>$($r.Role)</td><td style='color:$color;'>$($r.Health)</td></tr>"
    }
} catch {
    $issues += "AG check error: $_"
}
$html += "</table>"

#
# 2. Backup Status (last N hours)
#
$html += "<h2>Backup Status (last $backupThresholdHours hrs)</h2><table border='1' cellpadding='5'><tr><th>DB</th><th>Type</th><th>Last Backup</th><th>Status</th></tr>"
try {
    $bk = Invoke-Sqlcmd -ServerInstance $Instance -Query @"
        SELECT d.name AS DB,
               MAX(b.backup_finish_date) AS LastBackup,
               b.type AS Type
        FROM sys.databases d
        LEFT JOIN msdb.dbo.backupset b ON b.database_name = d.name
        WHERE d.name <> 'tempdb'
        GROUP BY d.name, b.type
"@
    foreach ($r in $bk) {
        $hours = if ($r.LastBackup) { (New-TimeSpan -Start $r.LastBackup -End (Get-Date)).TotalHours } else { [double]::MaxValue }
        if ($hours -le $backupThresholdHours) {
            $status = "OK"; $color = "green"
        } else {
            $status = "OUTDATED"; $color = "red"
            $issues += "$($r.DB) $($r.Type) backup $([math]::Round($hours,1)) hrs ago"
        }
        $lb = if ($r.LastBackup) { $r.LastBackup } else { "Never" }
        $html += "<tr><td>$($r.DB)</td><td>$($r.Type)</td><td>$lb</td><td style='color:$color;'>$status</td></tr>"
    }
} catch {
    $issues += "Backup check error: $_"
}
$html += "</table>"

#
# 3. Disk Space
#
$html += "<h2>Disk Space</h2><table border='1' cellpadding='5'><tr><th>Drive</th><th>Free GB</th><th>Total GB</th><th>Free %</th><th>Status</th></tr>"
try {
    $ds = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($d in $ds) {
        $free = [math]::Round($d.FreeSpace/1GB,2)
        $tot  = [math]::Round($d.Size/1GB,2)
        $pct  = [math]::Round(($free/$tot)*100,1)
        if ($pct -ge $diskFreeThresholdPercent) {
            $status = "OK"; $color = "green"
        } else {
            $status = "LOW"; $color = "red"
            $issues += "Drive $($d.DeviceID) $pct% free"
        }
        $html += "<tr><td>$($d.DeviceID)</td><td>$free</td><td>$tot</td><td>$pct%</td><td style='color:$color;'>$status</td></tr>"
    }
} catch {
    $issues += "Disk check error: $_"
}
$html += "</table>"

# Finalize HTML and write report
$html += "</body></html>"
$html -join "`n" | Out-File $ReportPath

# Send email if any issues
if ($issues.Count -gt 0) {
    $htmlBody = Get-Content -Path $ReportPath -Raw
    Send-MailMessage `
        -From       $from `
        -To         $to `
        -Subject    $subject `
        -Body       $htmlBody `
        -BodyAsHtml `
        -SmtpServer $smtpServer
}



