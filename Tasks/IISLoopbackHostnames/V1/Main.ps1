[CmdletBinding()]
param()

Clear-Host
Write-Verbose "Entering 'Test-IISLoopbackHostnames'..."

Trace-VstsEnteringInvocation $MyInvocation

$env:CURRENT_TASK_ROOTDIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module $env:CURRENT_TASK_ROOTDIR\ps_modules\VstsTaskSdk

. .\Utility.ps1

# Get Inputs
$hostnameLists = Get-VstsInput -Name HostNameLists -Require
$serverOption = Get-VstsInput -Name ServerOption -Require #Local or Remote
#== Advanced section ==
$disableLoopback = Get-VstsInput -Name DisableLoopback -AsBool
$resetAll = Get-VstsInput -Name ResetAll -AsBool
#== Security section ==
$adminUsername = ""
$adminPassword = ""

try 
{
    if ($serverOption -eq "Remote")
    {
        $machinesList = Get-VstsInput -Name machinesList -Require

        $result = Get-Thycotic
        $adminUsername = $result[0]
        $adminPassword = $result[1]
        #Write-Verbose ("Username: $adminUsername")
        #Write-Verbose ("Password: $adminPassword")

        $cred = Get-PSCredentials -username $adminUsername -password $adminPassword

        $machines = Get-ParseTargetMachineNames -machineNames $machinesList 
        foreach ($machine in $machines)
        {
            Write-Verbose "Invoking remote script: Set-IISLoopbackHostnames on '$machine'"
            Invoke-Command -Credential $cred -ComputerName $machine -FilePath ".\Set-IISLoopbackHostnames.ps1" -ArgumentList $hostnameLists, $disableLoopback, $resetAll -Verbose
        }
    }
    else 
    {
        $machineName = [System.Environment]::MachineName
        Write-Verbose "Running script: Set-IISLoopbackHostnames on '$machineName'"
        .\Set-IISLoopbackHostnames.ps1 -HostnameList $hostnameLists -DisableLoopback $disableLoopback -ResetAll $resetAll -Verbose
    }

    Write-Verbose "Script completed."    
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