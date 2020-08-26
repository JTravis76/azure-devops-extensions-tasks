[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

$env:CURRENT_TASK_ROOTDIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module $env:CURRENT_TASK_ROOTDIR\ps_modules\VstsTaskSdk

. .\Utility.ps1


<# == Test-DotNet ==
Desire Version will match against exact value. 
 If looking for a Major.Minor ONLY, place a x in the build spot.
 EX: 2.1.510 or 2.1.x or 2.1 

 TEST RESULTS for server version: '2.1.14':
 2.1.14   PASS
 2.1.141  FAIL
 2.1.x    PASS
 4.1.x    FAIL
 #>
# Get Inputs
$desireEnvironment = Get-VstsInput -Name DesireEnvironment
$desireVersion = Get-VstsInput -Name DesireVersion -Require
$serverOption = Get-VstsInput -Name ServerOption -Require # Local or Remote
#== Security section ==
$adminUsername = ""
$adminPassword = ""
#== Global Variables ==
$targetMachineNames = ""

if ($serverOption -eq "Remote") {
    $machinesList = Get-VstsInput -Name MachinesList -Require

    $account = Get-Thycotic
    $adminUsername = $account[0]
    $adminPassword = $account[1]

    $cred = Get-PSCredentials -username $adminUsername -password $adminPassword 

    $targetMachineNames = Get-ParseTargetMachineNames -machineNames $machinesList
}


try {
    $result = @()
    if ($serverOption -eq "Local") {
        $targetMachineNames = ([System.Environment]::MachineName)

        Write-Output "Checking ASPNETCORE_ENVIRONMENT on '$targetMachineNames'"

        $appEnv = $ENV:ASPNETCORE_ENVIRONMENT

        if ($appEnv -ne $desireEnvironment)
        {
            <# == Cannot update Environment variables on a server running the agent.
                  All agents must be restarted to see new values.
            #>
            #if ($setEnv)
            #{
            #    Write-Warning "Desire environment was not found. Updating environment to: $desireEnvironment."
            #    # Create/Set the variable
            #    $ENV:ASPNETCORE_ENVIRONMENT = $setEnv #<- this set to the current process
            #    [System.Environment]::SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT",$desireEnvironment,[System.EnvironmentVariableTarget]::Machine)

            #    Write-Warning "[WARN] When updating Environment Variables on servers running the agent, all agent services must be restarted."
            #}
            #else
            #{
                Write-Error "Server environment is mismatched. Found '$appEnv' instead of '$desireEnvironment'"
            #}
        }
        else
        {
            Write-Output "[PASS] Found environment: $desireEnvironment"
        }
        
        Write-Output "Checking installed DotNet runtimes on '$targetMachineNames'"
        $result = dotnet --list-runtimes
    }
    
    foreach ($targetMachineName in $targetMachineNames) {

        if ($serverOption -eq "Remote") {

            if ($desireEnvironment -ne "")
            {
                Write-Output "Checking ASPNETCORE_ENVIRONMENT on '$targetMachineName'"

                $appEnv = Invoke-Command -ComputerName $targetMachineName -ScriptBlock { $ENV:ASPNETCORE_ENVIRONMENT } -Credential $cred
            
                Write-Output "Current ASPNETCORE_ENVIRONMENT: $appEnv"

                if ($appEnv -ne $desireEnvironment)
                {
                    #Write-Output "##vso[task.LogIssue type=error;]Server environment is mismatched. Found '$appEnv' instead of '$desireEnvironment'"
                    Write-Error "Server environment is mismatched. Found '$appEnv' instead of '$desireEnvironment'"
                }
                else
                {
                    Write-Output "[PASS] Correct environment was found: $appEnv"
                }
            }

            Write-Output "Checking installed DotNet runtimes on '$targetMachineName'"

            $result = Invoke-Command -ComputerName $targetMachineName -ScriptBlock { dotnet --list-runtimes } -Credential $cred
        }

        Write-Verbose "Processing results..."
        
        $runtimeVersions = @()
        foreach ($s in $result) {
            if ($s -match '\d+.\d+.\d+' -and $s.Contains('Microsoft.NETCore.App')) {
                $runtimeVersions += $Matches[0]
            }
        }
        
        # Build error string
        $err = ( "Desired version '$desireVersion' was not found on target '$targetMachineName'. Found following: " + [string]::Join(",", $runtimeVersions) )
        
        Write-Verbose "Building temporary variables..."
        
        # flatten string[] into a string
        $s = ([string]::Join(",", $runtimeVersions))
        $v = $desireVersion
        
        if ($desireVersion.LastIndexOf(".x") -gt -1) {
            Write-Verbose "Removing the .x from the desired version..."
        
            # remove the Build and return just the Major.Minor
            $v = $desireVersion.Replace(".x", "")
        }
        
        Write-Verbose "Checking against desired version..."
        
        if ($s.IndexOf($v) -eq -1) {
            ## this option will continue execution
            Write-Error $err
                
            ## This will stop execution and close PShell ISE
            ## Recommended in Azure DevOps Tasks, but doesn't fail the task, only marks it 'completed with errors'
            #exit 1
        
            ## this option will stop the execution of the script
            #throw ($err)
        }
        else {
            Write-Output "[PASS] Correct version was found: $runtimeVersions."
        }
    }

    Write-Verbose "script completed."    
}
catch {    
    Write-Verbose $_.Exception.ToString() -Verbose
    throw
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
