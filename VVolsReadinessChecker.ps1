<#
******************************Disclaimer********************************
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
************************************************************************

This script will:
-Check for VVols Readiness
--Check for Purity 5.0.9+ or 5.1.3+
--Check for vCenter 6.5+ and ESXI 6.5+ (6.5 Update 1 is highly recommended)
--Check for communication from vCenter and ESXi hosts to FlashArray management ports on TCP port 8084
--Check that a NTP server is set, valid, and daemon running on ESXi hosts and FlashArray


All information logged to a file.

This can be run directly from PowerCLI or from a standard PowerShell prompt. PowerCLI must be installed on the local host regardless.

Supports:
-FlashArray //m and //x
-vCenter 6.5 and later
-PowerCLI 6.3 R1 or later required


#>

#Create log folder if non-existent
write-host ""
write-host "Please choose a directory to store the script log"
write-host ""
function ChooseFolder([string]$Message, [string]$InitialDirectory)
{
    $app = New-Object -ComObject Shell.Application
    $folder = $app.BrowseForFolder(0, $Message, 0, $InitialDirectory)
    $selectedDirectory = $folder.Self.Path
    return $selectedDirectory
}
$logfolder = ChooseFolder -Message "Please select a log file directory" -InitialDirectory 'MyComputer'
$logfile = $logfolder + '\' + (Get-Date -Format o |ForEach-Object {$_ -Replace ':', '.'}) + "checkvvols.log"

add-content $logfile '             __________________________'
add-content $logfile '            /++++++++++++++++++++++++++\'
add-content $logfile '           /++++++++++++++++++++++++++++\'
add-content $logfile '          /++++++++++++++++++++++++++++++\'
add-content $logfile '         /++++++++++++++++++++++++++++++++\'
add-content $logfile '        /++++++++++++++++++++++++++++++++++\'
add-content $logfile '       /++++++++++++/----------\++++++++++++\'
add-content $logfile '      /++++++++++++/            \++++++++++++\'
add-content $logfile '     /++++++++++++/              \++++++++++++\'
add-content $logfile '    /++++++++++++/                \++++++++++++\'
add-content $logfile '   /++++++++++++/                  \++++++++++++\'
add-content $logfile '   \++++++++++++\                  /++++++++++++/'
add-content $logfile '    \++++++++++++\                /++++++++++++/'
add-content $logfile '     \++++++++++++\              /++++++++++++/'
add-content $logfile '      \++++++++++++\            /++++++++++++/'
add-content $logfile '       \++++++++++++\          /++++++++++++/'
add-content $logfile '        \++++++++++++\'
add-content $logfile '         \++++++++++++\'
add-content $logfile '          \++++++++++++\'
add-content $logfile '           \++++++++++++\'
add-content $logfile '            \------------\'
add-content $logfile 'Pure Storage FlashArray VMware VVols Readiness Checker v1.0 (NOVEMBER-2018)'
add-content $logfile '----------------------------------------------------------------------------------------------------'

#Import PowerCLI. Requires PowerCLI version 6.3 or later. Will fail here if PowerCLI cannot be installed
#Will try to install PowerCLI with PowerShellGet if PowerCLI is not present.

if ((!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) -and (!(get-Module -Name VMware.PowerCLI -ListAvailable))) {
    if (Test-Path C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1 ù)
    {
        C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1 ù | out-null
    }
    elseif (Test-Path C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1ù)
    {
        C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1ù | out-null
    }
    elseif (!(get-Module -Name VMware.PowerCLI -ListAvailable))
    {
        if (get-Module -name PowerShellGet -ListAvailable)
        {
            try
            {
                Get-PackageProvider -name NuGet -ListAvailable -ErrorAction stop
            }
            catch
            {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false
            }
            Install-Module -Name VMware.PowerCLI  ìScope CurrentUser -Confirm:$false -Force"
        }
        else
        {
            write-host "PowerCLI could not automatically be installed because PowerShellGet is not present. Please install PowerShellGet or PowerCLI" -BackgroundColor Red
            write-host "PowerShellGet can be found here https://www.microsoft.com/en-us/download/details.aspx?id=51451 or is included with PowerShell version 5"
            write-host "Terminating Script" -BackgroundColor Red
            return
        }
    }
    if ((!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) -and (!(get-Module -Name VMware.PowerCLI -ListAvailable)))
    {
        write-host "PowerCLI not found. Please verify installation and retry." -BackgroundColor Red
        write-host "Terminating Script" -BackgroundColor Red
        return
    }
}
set-powercliconfiguration -invalidcertificateaction "ignore" -confirm:$false |out-null
if ((Get-PowerCLIVersion).build -lt 3737840)
{
    write-host "This version of PowerCLI is too old, version 6.3 Release 1 or later is required (Build 3737840)" -BackgroundColor Red
    write-host "Found the following build number:"
    write-host (Get-Module -Name VMware.PowerCLI).version
    write-host "Terminating Script" -BackgroundColor Red
    write-host "Get it here: https://my.vmware.com/group/vmware/get-download?downloadGroup=PCLI630R1"
    add-content $logfile "This version of PowerCLI is too old, version 6.3 Release 1 or later is required (Build 3737840)"
    add-content $logfile "Found the following build number:"
    add-content $logfile Get-Module -Name VMware.PowerCLI.version
    add-content $logfile "Terminating Script"
    add-content $logfile "Get it here: https://my.vmware.com/web/vmware/details?downloadGroup=PCLI650R1&productId=614"
    return
}
#connect to vCenter
$vcenter = read-host "Please enter a vCenter IP or FQDN"
$Creds = $Host.ui.PromptForCredential("vCenter Credentials", "Please enter your vCenter username and password.", "","")
try
{
    connect-viserver -Server $vcenter -Credential $Creds -ErrorAction Stop |out-null
}
catch
{
    write-host "Failed to connect to vCenter" -BackgroundColor Red
    write-host $Error
    write-host "Terminating Script" -BackgroundColor Red
    add-content $logfile "Failed to connect to vCenter"
    add-content $logfile $Error
    add-content $logfile "Terminating Script"
    return
}
write-host ""
write-host "Script result log can be found at $logfile" -ForegroundColor Green
write-host ""
add-content $logfile "Connected to vCenter at $($vcenter)"
add-content $logfile '----------------------------------------------------------------------------------------------------'

write-host "The default behavior is to check every host in vCenter."
$clusterChoice = read-host "Would you prefer to limit this to hosts in a specific cluster? (y/n)"

while (($clusterChoice -ine "y") -and ($clusterChoice -ine "n"))
{
    write-host "Invalid entry, please enter y or n"
    $clusterChoice = "Would you like to limit this check to a single cluster? (y/n)"
}
if ($clusterChoice -ieq "y")
{
    write-host "Please choose the cluster in the dialog box that popped-up." -ForegroundColor Yellow
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    #create form to choose recovery cluster
    $ClusterForm = New-Object System.Windows.Forms.Form
    $ClusterForm.width = 300
    $ClusterForm.height = 100
    $ClusterForm.Text = "ùChoose a Cluster"
    $DropDown = new-object System.Windows.Forms.ComboBox
    $DropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $DropDown.Location = new-object System.Drawing.Size(10,10)
    $DropDown.Size = new-object System.Drawing.Size(250,30)
    $clusters = get-cluster
    if ($clusters.count -lt 1)
    {
        add-content $logfile "Terminating Script. No VMware cluster(s) found."
        write-host "No VMware cluster(s) found. Terminating Script" -BackgroundColor Red
        Disconnect-VIServer $vcenter
        return
    }
    ForEach ($cluster in $clusters) {
        $DropDown.Items.Add($cluster.Name) |out-null
    }
    $ClusterForm.Controls.Add($DropDown)

    #okay button
    $OkClusterButton = new-object System.Windows.Forms.Button
    $OkClusterButton.Location = new-object System.Drawing.Size(60,40)
    $OkClusterButton.Size = new-object System.Drawing.Size(70,20)
    $OkClusterButton.Text = "OK"
    $OkClusterButton.Add_Click({
        $script:clusterName = $DropDown.SelectedItem.ToString()
        $ClusterForm.Close()
        })
    $ClusterForm.Controls.Add($OkClusterButton)

    #cancel button
    $CancelClusterButton = new-object System.Windows.Forms.Button
    $CancelClusterButton.Location = new-object System.Drawing.Size(150,40)
    $CancelClusterButton.Size = new-object System.Drawing.Size(70,20)
    $CancelClusterButton.Text = "Cancel"
    $CancelClusterButton.Add_Click({
        $script:endscript = $true
        $ClusterForm.Close()
        })
    $ClusterForm.Controls.Add($CancelClusterButton)
    $DropDown.SelectedIndex = 0
    $ClusterForm.Add_Shown({$ClusterForm.Activate()})
    [void] $ClusterForm.ShowDialog()

    add-content $logfile "Selected cluster is $($clusterName)"
    add-content $logfile ""
    $cluster = get-cluster -Name $clusterName
    $hosts = $cluster | get-vmhost
    write-host ""
}
else
{
    write-host ""
    $hosts = get-vmhost
}

#connect to FlashArray
$flasharray = read-host "Please enter a FlashArray IP or FQDN"
$Creds = $Host.ui.PromptForCredential("FlashArray Credentials", "Please enter your FlashArray username and password.", "","")
try
{
    $array = New-PfaArray -EndPoint $flasharray -Credentials $Creds -ErrorAction Stop -IgnoreCertificateError
}
catch
{
    write-host "Failed to connect to FlashArray" -BackgroundColor Red
    write-host $Error
    write-host "Terminating Script" -BackgroundColor Red
    add-content $logfile "Failed to connect to FlashArray"
    add-content $logfile $Error
    add-content $logfile "Terminating Script"
    return
}

$errorHosts = @()
write-host "Executing..."

# Check vCenter version
add-content $logfile "Working on the following vCenter: $($global:DefaultVIServers.name), version $($Global:DefaultVIServers.Version)"
add-content $logfile "-----------------------------------------------------------------------------------------------"
add-content $logfile "Checking vCenter Version"
add-content $logfile "-------------------------------------------------------"
if ($global:DefaultVIServers.version -le [Version]"6.5")
{
    add-content $logfile "[****NEEDS ATTENTION****] vCenter 6.5 or later is required for VMware VVols."
}
else
{
    add-content $logfile "Installed vCenter version, $($global:DefaultVIServers.version) supports VVols."
}

add-content $logfile "-----------------------------------------------------------------------------------------------"
add-content $logfile "vCSA NTP Notification"
add-content $logfile "-------------------------------------------------------"
add-content $logfile "[****NEEDS ATTENTION****] vCSA's NTP settings can't be checked remotely. Check VMware KB for manual process: https://kb.vmware.com/s/article/2113610."

# Iterating through each host in the vCenter
add-content $logfile ""
add-content $logfile "Iterating through all ESXi hosts in cluster $clusterName..."
$hosts | out-string | add-content $logfile
foreach ($esx in $hosts)
{
    add-content $logfile ""
    add-content $logfile "***********************************************************************************************"
    add-content $logfile "**********************************NEXT ESXi HOST***********************************************"
    add-content $logfile "-----------------------------------------------------------------------------------------------"
    add-content $logfile "Working on the following ESXi host: $($esx.Name), version $($esx.Version)"
    add-content $logfile "-----------------------------------------------------------------------------------------------"
    add-content $logfile "Checking ESXi Version"
    add-content $logfile "-------------------------------------------------------"
    # Check for ESXi version
    if ($esx.version -le [Version]"6.5")
    {
        add-content $logfile "[****NEEDS ATTENTION****] ESXi 6.5 or later is required for VMware VVols."
    }
    else
    {
        add-content $logfile "Installed ESXi version, $($esx.version) supports VVols."
    }
    add-content $logfile ""
    add-content $logfile "-------------------------------------------------------"
    add-content $logfile "Checking NTP settings"
    add-content $logfile "-------------------------------------------------------"

    # Check for NTP server configuration
    $ntpServer = Get-VMHostNtpServer -VMHost $esx
    if ($ntpServer -eq $null)
    {
       Add-Content $logfile "[****NEEDS ATTENTION****] NTP server for this host is null. Configure an NTP server before proceeding with VVols."
    }
    else
    {
        Add-Content $logfile "NTP server set to $($ntpServer)"
        $testNetConnection = Test-NetConnection -ComputerName $ntpserver -informationlevel Quiet
        if (!$testNetConnection)
        {
            Add-Content $logfile "[****NEEDS ATTENTION****] Could not communicate with NTP server. Check that it is valid and accessible."
        
        }
        else
        {
            Add-Content $logfile "NTP server is valid and accessible."
        }
    }

    # Check for NTP daemon running and enabled
    $ntpSettings = $esx | Get-VMHostService | Where-Object {$_.key -eq "ntpd"} | select vmhost, policy, running

    if ($ntpSettings."policy" -contains "off")
    {
        Add-Content $logfile "[****NEEDS ATTENTION****] NTP daemon not enabled. Enable service in host configuration."
    }
    else
    {
     Add-Content $logfile "NTP daemon is enabled."
    }

    if ($ntpSettings."running" -contains "true")
    {
        Add-Content $logfile "NTP daemon is running."
    }
    else
    {
        Add-Content $logfile "[****NEEDS ATTENTION****] NTP daemon is not running."
    }
}

# Check FlashArray's NTP Settings
$arrayid = Get-PfaArrayId -Array $array
add-content $logfile "***********************************************************************************************"
add-content $logfile "**********************************FLASHARRAY***************************************************"
add-content $logfile "-----------------------------------------------------------------------------------------------"
add-content $logfile "Working on the following FlashArray: $($flasharray), Purity version $($arrayid.version)"
add-content $logfile "-----------------------------------------------------------------------------------------------"
add-content $logfile "Checking NTP Setting"
add-content $logfile "-------------------------------------------------------"
$flashArrayNTP = Get-PfaNtpServers -Array $array
if (!$flashArrayNTP.ntpserver)
{
    Add-Content $logfile "[****NEEDS ATTENTION****] FlashArray does not have an NTP server configured."
}
else
{
    Add-Content $logfile "FlashArray has the following NTP server configured: $($flasharrayNTP.ntpserver)"
    [string]$ntpserver = $flashArrayNTP.ntpserver
    $testNetConnection = Test-NetConnection -ComputerName $ntpserver -informationlevel Quiet
    if (!$testNetConnection)
    {
        Add-Content $logfile "[****NEEDS ATTENTION****] Could not communicate with NTP server. Check that it is valid and accessible."
        
    }
    else
    {
        Add-Content $logfile "NTP server is valid and accessible."
    }
}
# Check Purity version
add-content $logfile ""
add-content $logfile "-------------------------------------------------------"
add-content $logfile "Checking Purity Version"
add-content $logfile "-------------------------------------------------------"

if ($arrayid.version -ge [Version]"5.0.9" -or $arrayid.version -ge [Version]"5.1.3")
{
    Add-Content $logfile "Purity version supports VVols."
}
else
{
    Add-Content $logfile "[****NEEDS ATTENTION****] Purity version does not support VVols. Contact Pure Storage support to upgrade to Purity version 5.1.3 or later."
}

# Check TCP port 8084 reachability
add-content $logfile ""
add-content $logfile "-------------------------------------------------------"
add-content $logfile "Checking FlashArray Reachability on TCP port 8084"
add-content $logfile "-------------------------------------------------------"

$arrayNetworkInterfaces = Get-PfaNetworkInterfaces -array $array
$testNetConnection = Test-NetConnection -ComputerName $flasharray -Port 8084 -InformationLevel Quiet
if (!$testNetConnection)
{
    Add-Content $logfile "[****NEEDS ATTENTION****] Could not reach FlashArray on TCP port 8084."
        
}
else
{
    Add-Content $logfile "FlashArray is reachable on TCP port 8084."
}

# Check for existance of hosts and host groups
add-content $logfile ""
add-content $logfile "-------------------------------------------------------"
add-content $logfile "Checking for Hosts and Host Groups"
add-content $logfile "-------------------------------------------------------"
$hostGroups = Get-PfaHostGroups -Array $array
if ($hostGroups.count -gt 0 -or $hostGroups.hosts.count -gt 0)
{
    Add-Content $logfile "FlashArray has host groups set."
    Add-Content $logfile "FlashArray has hosts set." 
}
else
{
    Add-Content $logfile "[****NEEDS ATTENTION****] FlashArray does not have any host or host groups configured."
}

Disconnect-PfaArray -Array $array
Disconnect-VIServer -server $vcenter