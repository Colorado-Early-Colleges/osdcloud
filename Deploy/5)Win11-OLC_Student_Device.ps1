#Script to deploy Windows 11 Lab environment using OSDCloud

# Prompt the user to enter the Asset Tag number
do {
    Write-Host -ForegroundColor Cyan "Please enter the asset tag number (3 to 5 digit number):"
    $assetTag = Read-Host
    if ($assetTag -match '^\d{3,5}$') {
        $assetTag | Out-File -FilePath "X:\OSDCloud\Config\Scripts\AssetTag.txt" -Encoding ascii -Force
    }
} while ($assetTag -notmatch '^\d{3,5}$')
Write-Output "You entered a valid asset tag number: $assetTag"

# Get the serial number of the machine
$serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
$serial = $serial.Trim()
# Check if serial is empty, null, or contains invalid values and replace it with the asset tag
if ([string]::IsNullOrWhiteSpace($serial) -or
    $serial -match "(fillded|system|defaultstring|none|to be filled|unknown|not specified|na|n/a|o.e.m.)") {
    $serial = $assetTag
}
# Construct the computer name
$computerName = "CECO-Student-$serial"
# Output the result
Write-Host "Generated Computer Name: $computerName" -ForegroundColor Yellow
# Save the computer name to a file
$computerName | Out-File -FilePath "X:\OSDCloud\Config\Scripts\ComputerName.txt" -Encoding ascii -Force


#================================================
# [PreODS] Set Bios Password
#================================================
# Check if Lenovo Bios Password has been set
$BiosPassState = Get-CimInstance -Namespace root/WMI -ClassName Lenovo_BiosPasswordSettings
If ($BiosPassState.PasswordState -eq 0) {
    #  Find Bios_Pass.txt and set $Passkey
    $Passkey = $null
    Foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $biosPassPath = Join-Path $drive.Root "Bios_Pass.txt"
        If (Test-Path $biosPassPath) {
            $Passkey = Get-Content $biosPassPath -Raw
            $Passkey = $Passkey.Trim()
            break
        }
    }
    If (-not $Passkey) {
        Write-Host -ForegroundColor Red "Bios_Pass.txt not found on any drive or file is empty."
        Write-Host -ForegroundColor White "Exiting Script..."
            Exit
    }
    Else {
        Write-Host -ForegroundColor Green "Bios_Pass.txt found."
        
        Write-Host -ForegroundColor Green "Setting BIOS Password"
        $setPw = Get-WmiObject -Namespace root/wmi -Class Lenovo_setBiosPassword
        $BiosPWStatus = $setPw.SetBiosPassword("pap,$Passkey,$Passkey,ascii,us")
        If ($BiosPWStatus.Return -eq "Success") {
            Write-Host -ForegroundColor white -BackgroundColor Green "BIOS Password set successfully." 
        }
        Else {
            Write-Host -ForegroundColor Red "Failed to set BIOS Password. Error code: $($BiosPWStatus.Return)"
            Write-Host -ForegroundColor Red "Please ensure you used System Deployment Boot Mode"
            Write-Host -ForegroundColor White "Exiting Script..."
            Exit
        }
    }
    
}
Else {
    Write-Host -ForegroundColor Yellow "BIOS Password already set, skipping..."
}
Write-Host -ForegroundColor Magenta "You can remove the flash drive."
Write-Host -ForegroundColor white -BackgroundColor Magenta "Hit enter to continue after drive has been removed..."
Pause

#================================================
Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
Install-Module OSD -Force

Write-Host  -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force

#=======================================================================
#   [OS] Params and Start-OSDCloud
#=======================================================================
$Params = @{
    OSVersion  = "Windows 11"
    OSBuild    = "25H2"
    OSEdition  = "Education"
    OSLanguage = "en-us"
    OSLicense  = "Volume"
    ZTI        = $true
    Firmware   = $true
}
Start-OSDCloud @Params

#================================================
#  [PostOS] OOBEDeploy Configuration
#================================================
Write-Host -ForegroundColor Green "Create C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json"
$OOBEDeployJson = @'
{
    "AddNetFX3":  {
                      "IsPresent":  true
                  },
    "Autopilot":  {
                      "IsPresent":  false
                  },
    "RemoveAppx":  [
                    "Microsoft.BingWeather",
                    "Microsoft.BingNews",
                    "Microsoft.GamingApp",
                    "Microsoft.GetHelp",
                    "Microsoft.Getstarted",
                    "Microsoft.Messaging",
                    "Microsoft.MicrosoftOfficeHub",
                    "Microsoft.MicrosoftSolitaireCollection",
                    "Microsoft.MicrosoftStickyNotes",
                    "Microsoft.People",
                    "Microsoft.PowerAutomateDesktop",
                    "Microsoft.StorePurchaseApp",
                    "Microsoft.Todos",
                    "microsoft.windowscommunicationsapps",
                    "Microsoft.WindowsFeedbackHub",
                    "Microsoft.WindowsMaps",
                    "Microsoft.Xbox.TCUI",
                    "Microsoft.XboxGameOverlay",
                    "Microsoft.XboxGamingOverlay",
                    "Microsoft.XboxIdentityProvider",
                    "Microsoft.XboxSpeechToTextOverlay",
                    "Microsoft.YourPhone",
                    "Microsoft.ZuneMusic",
                    "Microsoft.ZuneVideo"
                   ],
    "UpdateDrivers":  {
                          "IsPresent":  true
                      },
    "UpdateWindows":  {
                          "IsPresent":  true
                      }
}
'@
If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding ascii -Force

#================================================
#  [PostOS] AutopilotOOBE Configuration Staging
#================================================

# AssignedComputerName needs to be blank for Self-Deploying Autopilot
#$AssignedComputerName = Get-Content -Path "X:\OSDCloud\Config\Scripts\ComputerName.txt"

Write-Host -ForegroundColor Green "Create C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json"
$AutopilotOOBEJson = @"
{
    "AssignedComputerName" : "",
    "AddToGroup":  "Computer Config - BASE Win11 Labs",
    "Assign":  {
                   "IsPresent":  true
               },
    "GroupTag":  "Lab",
    "Hidden":  [
                   "AddToGroup",
                   "AssignedUser",
                   "PostAction",
                   "GroupTag",
                   "Assign",
                   "Docs"
               ],
    "PostAction":  "Restart",
    "Run":  "NetworkingWireless",
    "Title":  "CEC Autopilot Manual Register"
}
"@

If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$AutopilotOOBEJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json" -Encoding ascii -Force

#================================================
#  [PostOS] OOBE CMD Command Line
#================================================
Invoke-RestMethod https://raw.githubusercontent.com/Colorado-Early-Colleges/osdcloud/refs/heads/main/Set-LenovoAssetTag.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\set-lenovoassettag.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/Colorado-Early-Colleges/osdcloud/refs/heads/main/Lab_Rename-Computer.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\Lab_Rename-Computer.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/Colorado-Early-Colleges/osdcloud/refs/heads/main/Autopilot.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\autopilot.ps1' -Encoding ascii -Force

$OOBECMD = @'
@echo off

# Prompt for setting Lenovo Asset Tag
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\set-lenovoassettag.ps1

# Below a PS session for debug and testing in system context, # when not needed 
# start /wait powershell.exe -NoL -ExecutionPolicy Bypass

exit 
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  [PostOS] SetupComplete CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Create C:\Windows\Setup\Scripts\SetupComplete.cmd"
$SetupCompleteCMD = @'
powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\Lab_Rename-Computer.ps1
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Start Autopilot Import & Assignment Process</Description>
                    <Path>PowerShell -ExecutionPolicy Bypass C:\Windows\Setup\scripts\autopilot.ps1</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@

if (-NOT (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther'-ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$Panther = 'C:\Windows\Panther'
$UnattendPath = "$Panther\Unattend.xml"
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

Write-Host "Copying USB Drive Scripts"
Copy-Item X:\OSDCloud\Config\Scripts C:\OSDCloud\ -Recurse -Force

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot