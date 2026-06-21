<# PSScriptInfo
    .NOTES
        Source: 21/02/2018
        http://thinkdeploy.blogspot.com/2018/02/setting-asset-tag-on-thinkpads-with-mdm.html

    .DESCRIPTION
        This script will prompt for a Asset tag number and write the value to the BIOS of a Lenovo computer
#>

# Transcript for logging
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:OSDCloud\Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile -NoClobber
$VerbosePreference = "Continue"

# Intune PowerShell scripts can only be targeted at user groups not device groups
# If the local device Manufacturer is 'LENOVO' make changes
If ((Get-CimInstance -ClassName "Win32_ComputerSystem").Manufacturer -eq "LENOVO") {

    # Variables
    $input = Get-Content -Path $env:SystemDrive\OSDCloud\Scripts\AssetTag.txt
    $url = "https://download.lenovo.com/pccbbs/mobiles/giaw03ww.exe" # URL to WinAIA Utility
    $pkg = Split-Path $url -Leaf
    $tempDir = Join-Path (Join-Path $env:ProgramData "Lenovo") "Temp"
    $extractSwitch = "/VERYSILENT /DIR=$($tempDir) /EXTRACT=YES"
    
    # Create temp directory for utility and log output file 
    Write-Output "Creating Temp Directory"
    if ((Test-Path -Path $tempDir) -eq $false) {
        New-Item -Path $tempDir -ItemType Directory -Force
    }
 
    # Download utility via HTTPS
    Write-Output "Downloading WinAIA Utility"
    Invoke-WebRequest -Uri $url -Outfile "$tempdir\$pkg"
    If (Test-Path -Path "$tempdir\$pkg") {

        # Set location of WinAIA Package and extract contents
        Set-Location $tempDir
        Start-Process ".\$pkg" -ArgumentList $extractSwitch -Wait

        # Set Asset Number.  Available through WMI by querying the SMBIOSASSetTag field of the Win32_SystemEnclosure class
        Write-Output "Setting Asset Tag"
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set USERASSETDATA.ASSET_NUMBER=$input" -Wait
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set OWNERDATA.PHONE_NUMBER=$input" -Wait

        # Remove Package
        Write-Output "Removing Package"
        Remove-Item -LiteralPath $tempDir\$pkg -Force
    }
    Else {
        Write-Output "Failed to download $url"
    }
}
Else {

    # Local device is not from Lenovo
    Write-Output "Local system is not a Lenovo device. Exiting."
}

Stop-Transcript
