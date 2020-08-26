[CmdletBinding()]
param(
    [bool]$Test32,
    [bool]$Test64
)

Write-Verbose "Entering 'Use-CheckForIIS.ps1'."

$winService = "W3SVC"
$name = [System.Environment]::MachineName

Write-Output "Checking IIS installation on $name ..."
$v = Get-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\InetStp\ | Select-Object
Write-Output ($v[0].ProductString + ", " + $v[0].VersionString + " was found.")

Write-Output "Checking 'World Wide Web Publishing Service' ..."
$svc = Get-Service -Name $winService -ComputerName $name
Write-Output ($svc.Name + " was found.")

$service = Get-WmiObject -Class Win32_Service -ComputerName $name -Filter "name='$winService'"
Write-Output ("Service state is " + $service.State)

#== 32 bit installation
if ($Test32)
{
    Write-Output "Checking for 32 bit installation..."

    if ((Test-Path -Path "C:\Windows\System32\inetsrv" -PathType Container))
    {
        [xml]$xmlDoc = Get-Content -Path "C:\Windows\System32\inetsrv\Config\applicationHost.config"
        $global = $xmlDoc.SelectSingleNode('/configuration/system.webServer/globalModules/add[@name="CorsModule"]')
        if (!$global)
        {
            throw "applicationHost.config not setup correctly for IIS CORS module."
        }

        if(!(Test-Path -Path "C:\Windows\System32\inetsrv\iiscors.dll" -PathType Leaf))
        {
            throw "IIS CORS Module is not installed."
        }
        if(!(Test-Path -Path "C:\Windows\System32\inetsrv\Config\Schema\cors_schema.xml" -PathType Leaf))
        {
            throw "IIS CORS Module is not setup correctly. Missing cores.schema.xml"
        }
                                    
        Write-Output "32 bit IIS-CORS installation found."
    }
}
#== 64 bit installation
if ($Test64)
{
    Write-Output "Checking for 64 bit installation..."

    if ((Test-Path -Path "C:\Windows\SysWOW64\inetsrv" -PathType Container))
    {
        [xml]$xmlDoc = Get-Content -Path "C:\Windows\SysWOW64\inetsrv\Config\applicationHost.config"
        $global = $xmlDoc.SelectSingleNode('/configuration/system.webServer/globalModules/add[@name="CorsModule"]')
        if (!$global)
        {
            throw "applicationHost.config not setup correctly for IIS CORS module."
        }

        if(!(Test-Path -Path "C:\Windows\SysWOW64\inetsrv\iiscors.dll" -PathType Leaf))
        {
            throw "IIS CORS Module is not installed."
        }
        if(!(Test-Path -Path "C:\Windows\SysWOW64\inetsrv\Config\Schema\cors_schema.xml" -PathType Leaf))
        {
            throw "IIS CORS Module is not setup correctly. Missing cores.schema.xml"
        }

        Write-Output "64 bit IIS-CORS installation found."
    }
}