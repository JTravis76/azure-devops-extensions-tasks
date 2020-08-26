# PORTS - Build and Release Tools
Collection of handy Build and Release tasks for Azure DevOps CI/CD pipelines.
* Confirm DotNet Core
* Encrypt / Decrypt Web.config
* IIS CORS Module
* IIS Loopback Hostnames
* PORTS Window Machine File Copy



## Confirm DotNet Core

### Overview
The task is used to check for proper DotNet Core environment BEFORE deployment.

* **ASPNET Core Runtime Version**: the runtime version value to check against. Value can be Major.Minor.Revision or Major.Minor.x. Using `.x` in the revision will test the Major.Minor only.
* **ASPNET Core Environment**: assist in checking the environment variable is correctly set to either; Development, Staging, Production.

![Confirm DotNet Core](.\images\confirm-dotnet-core.png)


## Encrypt / Decrypt Web.config
### Overview
This task encrypt or decrypt various sections of the web.config file. This task should follow after a successful deployment.

* **Action**: action to be performed: Encrypt or Decrypt
* **Application Name**: name of the web application. Must start be a forward-slash `/`.
* **Site Name**: name of the site to apply action on. Default value is "Default Web Site".
* **Physical Directory**: directory path to the `web.config` file. **Note:** The Application and Site names are ignored.
* **App Settings**: performs action on the `appSettings`.
* **Connection Strings**: performs action on the `connectionStrings`.
* **Additional Section**: performs action on custom section of the web.config.
* **Location**: advance option to point to a different directory containing the aspnet_regiis.exe.

![Encrypt/Decrypt Config](.\images\encrypt-decrypt-config.png)

## IIS CORS Module
### Overview
This task in-sure the IIS in installed and service is running. Also confirms that IIS CORS Module is installed.

* **Check 32-bit installation**: check CORS module in the `C:\Windows\System32\inetsrv`. This normally is the default.
* **Check 64-bit installation**: check CORS module in the `C:\Windows\SysWOW64\inetsrv`. 

## IIS Loopback Hostnames
### Overview
Task will add hostnames to allow IIS to omit additional security check when hosting both web front-end and back-end using a custom hostname.

* **Hostnames**: list of hostnames to append to the existing list.
* **Disable Loopback**: this advance option will turn off loopback checking for the entire web server.
* **Reset All**: this advance option will first clear any existing hostnames before adding those in the hostnames field.

![IIS Loopback Hostnames](.\images\iis-hostname.png)


## PORTS Windows Machine File Copy
> This extension is built-in to Azure DevOps from Microsoft and was updated to support Thycotic Secret Server. Currently, there is not option to update built-in extensions. Had to clone project and generate a new task.

### Overview
The task is used to copy application files and other artifacts that are required to install the application on Windows Machines like PowerShell scripts, PowerShell-DSC modules etc. The task provides the ability to copy files to Windows Machines. The tasks uses RoboCopy, the command-line utility built for fast copying of data.

### The different parameters of the task are explained below:

*	**Source**: The source of the files. As described above using pre-defined system variables like $(Build.Repository.LocalPath) make it easy to specify the location of the build on the Build Automation Agent machine. The variables resolve to the working folder on the agent machine, when the task is run on it. Wild cards like **\*.zip are not supported.
* **Machines**: Specify comma separated list of machine FQDNs/ip addresses along with port(optional). For example dbserver.fabrikam.com, dbserver_int.fabrikam.com:5986,192.168.34:5986. 
*	**Destination Folder**: The folder in the Windows machines where the files will be copied to. An example of the destination folder is c:\FabrikamFibre\Web.
*	**Clean Target**: Checking this option will clean the destination folder prior to copying the files to it.
*	**Copy Files in Parallel**: Checking this option will copy files to all the target machines in parallel, which can speed up the copying process.


## Advanced
### Thycotic
Many of these tasks as remote support either via username/password or Thycotic Secret Server. To achieved this, Thycotic SDK must be setup on server running the VSTS agent. Below are the steps to setup the environment.

* First, download and unzip the Thycotic SDK to `C:\secretserver-sdk-1.4.1-win-x64\`
* Next steps will allow the SDK to store the thycotic cache in the desired directory.
    * Create an empty command file; `tss.cmd`
        * save the file under `C:\Windows\`
        * Open tss.cmd and paste content. Then save & close.
        ```
        @echo Off 
        "C:\secretserver-sdk-1.4.1-win-x64\tss.exe" "-kd" "E:\Thycotic" "-cd" "E:\Thycotic\SDK" %*
        ```
    > If agent cannot run or locate `tss` command, then restart **ALL** VSTS agents running on the server.


Thycotic field descriptions.

* **Authentication**: Standard option with provide the default username/password. Thycotic option when query secret server for the username/password based on the secret id.
* **Admin Login**: Domain/Local administrator of the target host. Format: &lt;Domain or hostname&gt;\ &lt; Admin User&gt;.  
* **Password**:  Password for the admin login. It can accept variable defined in Build/Release definitions as '$(passwordVariable)'. You may mark variable type as 'secret' to secure it.
* **Server URL**: Address of a Thycotic server.
* **Rule Name**: Name of the rule.
* **Key**:  Name of the key.
* **Secret Id**: Id of secret to query.

![Thycotic Properties](.\images\thycotic-properties.png)

### Setup & Building

```
:: Install the cli
npm i -g tfx-cli

:: add module to each task
:: may need to move files up one directory, then delete the version folder.
Save-Module -Name VstsTaskSdk -Path .\Tasks\ConfirmDotNet\ps_modules
Save-Module -Name VstsTaskSdk -Path .\Tasks\EncryptDecryptConfig\ps_modules
Save-Module -Name VstsTaskSdk -Path .\Tasks\IISCorsModule\ps_modules
Save-Module -Name VstsTaskSdk -Path .\Tasks\IISLoopbackHostnames\ps_modules
Save-Module -Name VstsTaskSdk -Path .\Tasks\WindowsMachineFileCopy\ps_modules

:: Create the visx extension package
tfx extension create --manifest-globs vss-extension.json

:: Or, to auto rev the next version
tfx extension create --rev-version
```