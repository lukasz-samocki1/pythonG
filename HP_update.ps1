<#
.Name
    win11image4hp.ps1

.Synopsis
    script used by OSDcloud to install Windows 11 image on HP business devices

.DESCRIPTION
    script used by OSDcloud to install Windows 11 image on HP business devices

.Notes  
    Author: Tomasz Omelaniuk/HP Inc based on garytown blog

 .Examples
    Edit-OSDCloudWinPE -StartURL https://URL_to_the_script_/win11image4hp.ps1 -DriverPath C:\workspace_with_WINPE_drivers\DRIVERS -PSModuleInstall HPCMSL
#>

#### functions definitions
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}

function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}

function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray '========================================================================='
}

function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}

function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#### end of functions definitions

#### VARIABLES definitions
$ScriptName = 'OSDcloud script based on code from Gary'
$ScriptVersion = '25.08.19'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer

#### important OS variables
$OSVersion = 'Windows 11' 	#Used to Determine Driver Pack
$OSReleaseID = '23H2' 		#Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Retail'
$OSLanguage = 'pl-pl'

#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$false
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$false
    WindowsDefenderUpdate = [bool]$false
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

write-host -ForegroundColor DarkGray "========================================================="
write-host -ForegroundColor Cyan "HP Functions"

#HPIA Functions
Write-Host -ForegroundColor Green "[+] Function Get-HPIALatestVersion"
Write-Host -ForegroundColor Green "[+] Function Install-HPIA"
Write-Host -ForegroundColor Green "[+] Function Run-HPIA"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAXMLResult"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAJSONResult"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/HPIA/HPIA-Functions.ps1)

#HP CMSL WinPE replacement
Write-Host -ForegroundColor Green "[+] Function Get-HPOSSupport"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqListLatest"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqItems"
Write-Host -ForegroundColor Green "[+] Function Get-HPDriverPackLatest"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Test-HPIASupport.ps1)

#Install-ModuleHPCMSL
Write-Host -ForegroundColor Green "[+] Function Install-ModuleHPCMSL"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/EMPS/Install-ModuleHPCMSL.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-HPAnalyzer"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPDriverUpdate"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/EMPS/Invoke-HPDriverUpdate.ps1)

#Enable HPIA | Update HP BIOS | Update HP TPM 
if (Test-HPIASupport){
    Write-SectionHeader -Message "Detected HP Device, Enabling HPIA, HP BIOS and HP TPM Updates"
    $Global:MyOSDCloud.DevMode = [bool]$true
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$true
	
    $Global:MyOSDCloud.HPIAALL = [bool]$false
	$Global:MyOSDCloud.HPIADrivers = [bool]$true
    $Global:MyOSDCloud.HPIASoftware = [bool]$false
    $Global:MyOSDCloud.HPIAFirmware = [bool]$true	
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPBIOSWinUpdate = [bool]$false   
    
	write-host "Setting DriverPackName to 'None'"
    $Global:MyOSDCloud.DriverPackName = "None"
}

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID
if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#write variables to console
Write-SectionHeader "OSDCloud Variables"
Write-Output $Global:MyOSDCloud

#Launch OSDCloud
Write-SectionHeader -Message "Starting OSDCloud"
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
Write-SectionHeader -Message "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot"

#### driver pack unpacking, removing and injecting
$driverpackDetails = Get-HPDriverPackLatest
$driverpackID = $driverpackDetails.Id
[string]$ToolLocation = "C:\Drivers"

$ToolPath = "$ToolLocation\$driverpackID.exe"
if (!(Test-Path -Path $ToolPath)){
    Write-Output "Unable to find $ToolPath"
	pause
    Exit -1
}

$ToolArg = "/s /f C:\Drivers\"
$Process = Start-Process -FilePath $ToolPath -ArgumentList $ToolArg -Wait -PassThru

Dism /Image:C: /Add-Driver /Driver:C:\Drivers /Recurse

#### cleaning drivers 
remove-item $ToolPath -Force
$ToolPath = "$ToolLocation\$driverpackID.cva"
remove-item $ToolPath -Force

Remove-Item -Path C:\Drivers\ -Recurse -Force

#### adding some OOBE configuration
xcopy D:\unattended-basic-config.xml c:\Windows\System32\Sysprep\Panther\Unattend\Unattend.xml /-I
xcopy D:\unattended-basic-config.xml c:\Windows\System32\Sysprep\Unattend.xml /-I
xcopy D:\unattended-basic-config.xml c:\Windows\System32\Sysprep\Panther\Unattend\Autounattend.xml /-I
xcopy D:\unattended-basic-config.xml c:\Windows\System32\Sysprep\Autounattend.xml /-I

#Restart
restart-computer

