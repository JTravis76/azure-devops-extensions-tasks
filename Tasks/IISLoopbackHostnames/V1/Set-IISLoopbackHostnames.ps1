<#== IIS CORS with Windows Authentication and Custom Hostname/HostHeader

https://stackoverflow.com/questions/48183054/iis-windows-authentication-with-dns

Option 1: Add SPN entries
https://docs.microsoft.com/en-us/archive/blogs/jaws/spn-configurations-for-kerberos-authentication-a-quick-reference
setspn -S http/hostname servername

Option 2: Disable the looback check
> There is two ways to disable. 
* "DisableLoopbackCheck" = 1 allows ALL hostnames.
* "BackConnectionHostNames" = restricts to certain hostnames

```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa]
"DisableLoopbackCheck"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0]
"BackConnectionHostNames"=hex(7):6d,00,79,00,61,00,70,00,70,00,6c,00,6f,00,63,\
  00,61,00,6c,00,00,00,00,00
```
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $HostnameList,
    [int] $DisableLoopback,
    [bool] $ResetAll
)

Write-Verbose "Entering 'Set-IISLoopbackHostnames'..."

#== Reset ALL ==
if ($ResetAll -eq $True)
{
    try {
        Write-Output "Clearing ALL settings..."

        Remove-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Lsa" -Name "DisableLoopbackCheck"
        Remove-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "BackConnectionHostNames"    
    }
    catch [System.Exception] {
        # do nothing, supress message
    }
}


#== DisableLoopbackCheck ==
$path1 = "HKLM:SYSTEM\CurrentControlSet\Control\Lsa"
try
{
    Write-Verbose "Testing if registry path exist for 'DisableLoopbackCheck'."
    $v = Get-ItemPropertyValue -Path $path1 -Name "DisableLoopbackCheck"

    Write-Output "Updating 'DisableLoopbackCheck' to $DisableLoopback"
    Set-ItemProperty -Path $path1 -Name "DisableLoopbackCheck" -Value $disbableLoopback
}
catch [System.Exception]
{
    Write-Warning $_

    Write-Output "Creating and setting 'DisableLoopbackCheck' to $DisableLoopback"
    $v = New-ItemProperty -Path $path1 -PropertyType "DWord" -Name "DisableLoopbackCheck" -Value 1 #$disbableLoopback
}

#== BackConnectionHostNames ==
$path2 = "HKLM:SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
try
{
    Write-Verbose "Testing if registry path exist for 'BackConnectionHostNames'"
    $list = Get-ItemPropertyValue -Path $path2 -Name "BackConnectionHostNames"
    
    # flatten string[] into a string
    $s = ([string]::Join(",", $list))

    $hostnames = $HostnameList.Split(',')
    foreach ($hostname in $hostnames)
    {
        if ($s.IndexOf($hostname) -eq -1) 
        {
            Write-Verbose "Appending '$hostname' to list."
            $list += $hostname
        }
    }
    
    Write-Output "Updating 'BackConnectionHostNames' registry."
    Set-ItemProperty -Path $path2 -Name "BackConnectionHostNames" -Value $list
}
catch [System.Exception]
{
    Write-Warning $_

    $hostnames = $HostnameList.Split(',')
    Write-Output "Creating and setting 'BackConnectionHostNames' to $hostnames ."
    $v = New-ItemProperty -Path $path2 -PropertyType "MultiString" -Name "BackConnectionHostNames" -Value $hostnames
}

return ""