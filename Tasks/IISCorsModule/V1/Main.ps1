[CmdletBinding()]
param()

    Write-Verbose "Entering 'Main.ps1'..."

    Trace-VstsEnteringInvocation $MyInvocation
    
    $env:CURRENT_TASK_ROOTDIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Import-Module $env:CURRENT_TASK_ROOTDIR\ps_modules\VstsTaskSdk
    
    . .\Utility.ps1
    
    # Get Inputs
    $test32 = Get-VstsInput -Name Test32 -AsBool
    $test64 = Get-VstsInput -Name Test64 -AsBool
    $serverOption = Get-VstsInput -Name ServerOption -Require #Local or Remote
    #== Advanced section ==
    
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
                Write-Verbose "Invoking remote script: Use-CheckForIIS on '$machine'"
                Invoke-Command -Credential $cred -ComputerName $machine -FilePath ".\Use-CheckForIIS.ps1" -ArgumentList $test32, $test64 -Verbose
            }
        }
        else 
        {
            $machineName = [System.Environment]::MachineName
            Write-Verbose "Running script: Use-CheckForIIS on '$machineName'"
            .\Use-CheckForIIS.ps1 -Test32 $test32 -Test64 $test64 -Verbose
        }                
    }
    catch
    {    
        Write-Verbose $_.Exception.ToString() -Verbose
        throw $_
    }
    finally
    {
        Write-Verbose "Script completed."
        Trace-VstsLeavingInvocation $MyInvocation
    }
