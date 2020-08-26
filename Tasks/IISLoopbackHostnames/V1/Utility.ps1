function Get-PSCredentials {
    param (
        [string][AllowNull()] $username, 
        [string][AllowNull()] $password 
    )

    Write-Verbose "Building PSCredential..."

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
        return $null
    }

    $secretPassword = "$password" | ConvertTo-SecureString -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ("$username", $secretPassword)

    return $credentials
}

function Format-SpecialChars
{
    param(
        [string] $str,
        [switch] $secret
    )

    $escapedStr = $str.Replace('`', '``').Replace('"', '`"').Replace('$', '`$')

    if ($secret) 
    {
        # mask both original and escaped string if it is a secret variable
        Write-Host "##vso[task.setvariable variable=f13679253bf44b74afbd244ae83ca735;isSecret=true]$str"
        Write-Host "##vso[task.setvariable variable=f13679253bf44b74afbd244ae83ca735;isSecret=true]$escapedStr"
    }

    return $escapedStr
}

function Get-ParseTargetMachineNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $machineNames,
        [ValidateNotNullOrEmpty()]
        [char] $separator = ','
    )

    Write-Verbose "Executing Get-ParseTargetMachineNames"
    try {
        $targetMachineNames = $machineNames.ToLowerInvariant().Split($separator) |
        # multiple connections to the same machine are filtered here
            Select-Object -Unique |
                ForEach-Object {
                    if (![string]::IsNullOrEmpty($_)) {
                        Write-Verbose "TargetMachineName: '$_'" ;
                        $_.ToLowerInvariant()
                    } 
                }

        return ,$targetMachineNames;
    }
    finally {   
        Write-Verbose "Finished executing Parse-TargetMachineNames"
    }
}

function Use-Command
{
    param(
        [string]$command,
        [bool] $failOnErr = $true
    )

    $ErrorActionPreference = 'Continue'

    if( $psversiontable.PSVersion.Major -le 4)
    {
        $result = cmd.exe /c "`"$command`""
    }
    else
    {
        $result = cmd.exe /c "$command"
    }

    $ErrorActionPreference = 'Stop'

    if($failOnErr -and $LASTEXITCODE -ne 0)
    {
        throw $result
    }

    return $result
}

function Test-Inputs {
    param (
        [string] $virtualPath
    )

    if ((-not [string]::IsNullOrWhiteSpace($virtualPath)) -and (-not $virtualPath.StartsWith("/"))) {
        throw ("Virtual path should begin with a /")
    }
}

function CheckLogAndOutput {
    param ($log)
    
    if ($log[4].Contains("Succeeded") ) {
        Write-Verbose "Succeeded!"
    }
    else {
        Write-Verbose "##vso[task.logissue type=warning]" $log[4]
    }
}

function Get-Thycotic {
    [CmdletBinding()]
    param()

    Write-Verbose "Entering 'Get-Thycotic'..."

    # Standard or Thycotic
    $winRmAuthentication = Get-VstsInput -Name WinRmAuthentication -Require  
    if ($winRmAuthentication -eq "Standard") {
        $adminUserName = Get-VstsInput -Name AdminUserName -Require
        $adminPassword = Get-VstsInput -Name AdminPassword -Require
    }
    else {
        $thycoticServer = Get-VstsInput -Name ThycoticServer -Require
        $thycoticRule = Get-VstsInput -Name ThycoticRule -Require
        $thycoticKey = Get-VstsInput -Name ThycoticKey -Require
        $thycoticSecretId = Get-VstsInput -Name ThycoticSecretId -Require

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
}