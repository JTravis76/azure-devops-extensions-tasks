[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

# Get inputs for the task
$machineNames = Get-VstsInput -Name MachineNames -Require
$adminUserName = ""
$adminPassword = ""

$winRmAuthentication = Get-VstsInput -Name WinRMAuthentication
if ($winRmAuthentication -eq "Standard")
{
    $adminUserName = Get-VstsInput -Name AdminUserName -Require
    $adminPassword = Get-VstsInput -Name AdminPassword -Require
}
else
{
    $thycoticServer = Get-VstsInput -Name ThycoticServer -Require
    $thycoticRule = Get-VstsInput -Name ThycoticRule -Require
    $thycoticKey = Get-VstsInput -Name ThycoticKey -Require
    $thycoticSecretId = Get-VstsInput -Name ThycoticSecretId -Require

    # First set the Secret Server environment
    # Then, fetch secret and apply to admin username and password
    # Note: WINRM seems to like user name is this format; user@domain
    try {
        $v = tss remove -c
        Write-Verbose $v[0]
        $v = tss init -u $thycoticServer -r $thycoticRule -k $thycoticKey
        Write-Verbose $v[0]
        $secret = tss secret -s $thycoticSecretId

        if ($secret[0] -eq "400 - Bad Request")
        {
            throw "Access Denied to secret id: $thycoticSecretId"
        }

        $domain = ""
        $username = ""

        $thycotic = $secret | ConvertFrom-Json
        foreach ($i in $thycotic.items)
        {
            if ($i.fieldName -eq "Domain")
            {
                $domain = $i.itemValue
            }
            if ($i.fieldName -eq "Username")
            {
                $username = $i.itemValue
            }
            if ($i.fieldName -eq "Password")
            {
                $adminPassword = $i.itemValue
            }
        }
        if ($username -eq "" -or $domain -eq "")
        {
            throw "Invalid username and/or domain."
        }
        $adminUserName = ($username + "@" + $domain)  
    }
    catch [System.Exception] {
        Write-Host ("##vso[task.LogIssue type=error;]Error within Thycotic Secret Server. Please check your settings.")
        Write-Host $_
    }
}
$sourcePath = Get-VstsInput -Name SourcePath -Require
$targetPath = Get-VstsInput -Name TargetPath -Require
$additionalArguments = Get-VstsInput -Name AdditionalArguments
$cleanTargetBeforeCopy = Get-VstsInput -Name CleanTargetBeforeCopy
$copyFilesInParallel = Get-VstsInput -Name CopyFilesInParallel

# Import the loc strings.
Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json

. $PSScriptRoot/RoboCopyJob.ps1
. $PSScriptRoot/Utility.ps1

try 
{
    $sourcePath = $sourcePath.Trim('"')
    $targetPath = $targetPath.Trim('"')

    # Normalize admin username
    if($adminUserName -and (-not $adminUserName.StartsWith(".\")) -and ($adminUserName.IndexOf("\") -eq -1) -and ($adminUserName.IndexOf("@") -eq -1))
    {
        $adminUserName = ".\" + $adminUserName 
    }

    $envOperationStatus = 'Passed'

    Validate-SourcePath $sourcePath
    Validate-DestinationPath $targetPath $machineNames

    $machines = $machineNames.split(',') | ForEach-Object { if ($_ -and $_.trim()) { $_.trim() } }

    $secureAdminPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
    $machineCredential = New-Object System.Net.NetworkCredential ($adminUserName, $secureAdminPassword)

    if ($machines.Count -eq 0)
    {
        throw (Get-VstsLocString -Key "WFC_NoMachineExistsUnderEnvironment0ForDeployment" -ArgumentList $machineNames)
    }

    if($copyFilesInParallel -eq $false -or  ( $machines.Count -eq 1 ))
    {
        foreach($machine in $machines)
        {

            Write-Output (Get-VstsLocString -Key "WFC_CopyStartedFor0" -ArgumentList $machine)

            Invoke-Command -ScriptBlock $CopyJob -ArgumentList $machine, $sourcePath, $targetPath, $machineCredential, $cleanTargetBeforeCopy, $additionalArguments, $PSScriptRoot
        } 
    }
    else
    {
        [hashtable]$Jobs = @{} 

        foreach($machine in $machines)
        {

            Write-Output (Get-VstsLocString -Key "WFC_CopyStartedFor0" -ArgumentList $machine)

            $job = Start-Job -ScriptBlock $CopyJob -ArgumentList $machine, $sourcePath, $targetPath, $machineCredential, $cleanTargetBeforeCopy, $additionalArguments, $PSScriptRoot

            $Jobs.Add($job.Id, $machine)
        }        

        While ($Jobs.Count -gt 0)
        {
            Start-Sleep 10 
            foreach($job in Get-Job)
            {
                if($Jobs.ContainsKey($job.Id) -and $job.State -ne "Running")
                {
                    Receive-Job -Id $job.Id
                    Remove-Job $Job                 
                    $Jobs.Remove($job.Id)
                } 
            }
        }
    }

}
catch
{
    Write-Verbose $_.Exception.ToString() -Verbose
    throw
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}