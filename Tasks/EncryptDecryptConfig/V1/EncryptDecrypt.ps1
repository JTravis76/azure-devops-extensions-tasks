Function Run
{
[CmdletBinding()]
param()

# Get all inputs
$action = Get-VstsInput -Name Action -Require
$configPath = Get-VstsInput -Name ConfigPath
$appSettings = Get-VstsInput -Name AppSettings
$connectionStrings = Get-VstsInput -Name ConnectionStrings
$additionalSection = Get-VstsInput -Name AdditionalSection
$aspNetRegIISLocation = Get-VstsInput -Name AspNetRegIISLocation

if ($configPath -eq "")
{
    $app = Get-VstsInput -Name App
    $site = Get-VstsInput -Name Site

    if ($app -eq "") { $app = "/" }
    if ($site -eq "") { $site = "Default Web Site" }    
}
if ($aspNetRegIISLocation -eq "")
{
    $aspNetRegIISLocation = "C:\Windows\Microsoft.NET\Framework\v4.0.30319"
}
Set-Location -Path $aspNetRegIISLocation
$log = @()

# Encrypt
if ($action -eq "Encrypt")
{
    if ($appSettings -eq "true") 
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Encrypting [appSettings] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pe "appSettings" -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else
        {
            Write-Host ("== Encrypting [appSettings] for " + $configPath)
            $log = .\aspnet_regiis.exe -pef "appSettings" $configPath
            CheckLogAndOutput -log $log
        }
    }
    if ($connectionStrings -eq "true")
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Encrypting [connectionStrings] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pe "connectionStrings" -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else 
        {
            Write-Host ("== Encrypting [connectionStrings] for " + $configPath)
            $log = .\aspnet_regiis.exe -pef "connectionStrings" $configPath
            CheckLogAndOutput -log $log
        }
    }
    if ($additionalSection -ne "")
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Encrypting [" + $additionalSection + "] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pe $additionalSection -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else 
        {
            Write-Host ("== Encrypting [" + $additionalSection + "] for " + $configPath)
            $log = .\aspnet_regiis.exe -pef $additionalSection $configPath  
            CheckLogAndOutput -log $log 
        }
    }
}
else 
{
    # Decrypt
    if ($appSettings -eq "true") 
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Decrypting [appSettings] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pd "appSettings" -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else
        {
            Write-Host ("== Decrypting [appSettings] for " + $configPath)
            $log = .\aspnet_regiis.exe -pdf "appSettings" $configPath
            CheckLogAndOutput -log $log
        }
    }
    if ($connectionStrings -eq "true")
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Decrypting [connectionStrings] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pd "connectionStrings" -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else 
        {
            Write-Host ("== Decrypting [connectionStrings] for " + $configPath)
            $log = .\aspnet_regiis.exe -pdf "connectionStrings" $configPath
            CheckLogAndOutput -log $log 
        }
    }
    if ($additionalSection -ne "")
    {
        if ($configPath -eq "")
        {
            Write-Host ("== Decrypting [" + $additionalSection + "] for " + $site + " " + $app)
            $log = .\aspnet_regiis.exe -pd $additionalSection -app $app -site $site
            CheckLogAndOutput -log $log
        }
        else 
        {
            Write-Host ("== Decrypting [" + $additionalSection + "] for " + $configPath)
            $log = .\aspnet_regiis.exe -pdf $additionalSection $configPath
            CheckLogAndOutput -log $log
        }
    }  
}

}
Function CheckLogAndOutput {
    param ($log)
    
    if ($log[4].Contains("Succeeded") )
    {
        Write-Host "Succeeded!"
    }
    else {
        Write-Host "##vso[task.logissue type=warning]" $log[4]
    }
}

Run