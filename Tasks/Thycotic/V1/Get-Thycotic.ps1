[CmdletBinding()]
param()

    Write-Verbose "Entering 'Get-Thycotic'..."

    # Standard or Thycotic
    $winRmAuthentication = Get-VstsInput -Name WinRmAuthentication -Default "Thycotic" #-Require  
    if ($winRmAuthentication -eq "Standard") {
        $adminUserName = Get-VstsInput -Name AdminUserName -Require
        $adminPassword = Get-VstsInput -Name AdminPassword -Require
    }
    else {
        $thycoticServer = Get-VstsInput -Name ThycoticServer -Default "https://domain.local/SecretServer/" #-Require
        $thycoticRule = Get-VstsInput -Name ThycoticRule -Default "SomeRule" #-Require
        $thycoticKey = Get-VstsInput -Name ThycoticKey -Default "SomeKey" #-Require
        $thycoticSecretId = Get-VstsInput -Name ThycoticSecretId -Default "SomeId" #-Require

        # First set the Secret Server environment
        # Then, fetch secret and apply to admin username and password
        # Note: WINRM seems to like user name is this format; user@domain
        try {
            Write-Verbose "Reinitiate Thycotic user and fetching secret..."

            $v = tss remove -c
            Write-Verbose $v[0]
            $v = tss init -u $thycoticServer -r $thycoticRule -k $thycoticKey
            Write-Verbose $v[0]
            $user = tss secret -s $thycoticSecretId -f username

            if ($user[0] -eq "400 - Bad Request")
            {
                throw "Access Denied to secret id: $thycoticSecretId"
            }
            $domain = tss secret -s $thycoticSecretId -f domain
            $adminUserName = ($user + "@" + $domain)
            $adminPassword = tss secret -s $thycoticSecretId -f password   
        }
        catch [System.Exception] {
            Write-Host ("##vso[task.LogIssue type=error;]Error within Thycotic Secret Server. Please check your settings.")
            Write-Host $_
        }
    }

    $result = @()
    $result += $adminUserName
    $result += $adminPassword
    return $result;