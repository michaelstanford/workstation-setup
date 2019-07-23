if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

function Check-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Rename Computer -----------------------------------------------------------------------------
$computerName = Read-Host 'Enter New Computer Name'
Write-Host "Renaming this computer to: " $computerName  -ForegroundColor Yellow
Rename-Computer -NewName $computerName -Force

# Disable sleep when plugged in to power -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Disable Sleep on AC Power..." -ForegroundColor Green
Write-Host "------------------------------------" -ForegroundColor Green
Powercfg /Change monitor-timeout-ac 20
Powercfg /Change standby-timeout-ac 0

# Enable developer mode -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Enable Windows 10 Developer Mode..." -ForegroundColor Green
Write-Host "------------------------------------" -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"


# Enable Remote Desktop -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Enable Remote Desktop..." -ForegroundColor Green
Write-Host "------------------------------------" -ForegroundColor Green
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\" -Name "fDenyTSConnections" -Value 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\" -Name "UserAuthentication" -Value 1
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"


# Enable WSL ------------------------------------------------------------------------------------
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

# Download Ubuntu ------------------------------------------------------------------------------------
Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1604 -OutFile Ubuntu.appx -UseBasicParsing

# Install Ubuntu ------------------------------------------------------------------------------------
Rename-Item ./Ubuntu.appx ./Ubuntu.zip
Expand-Archive ./Ubuntu.zip ./Ubuntu


#opens PC to This PC, not quick access
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Value 1

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName containers -All -NoRestart

# installing Windows Template Studio VSIX
Write-Host "Installing Windows Template Studio" -ForegroundColor "Yellow"

$requestUri = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery";
$requestBody = '{"flags":"262","filters":[{"criteria":[{"filterType":"10","value":"windows template studio"}],"sortBy":"0","sortOrder":"2","pageSize":"25","pageNumber":"1"}]}';
$requestHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]";
$requestHeaders.Add('Accept','application/json; api-version=3.2-preview.1');
$requestHeaders.Add('Content-Type','application/json; charset=utf-8');

$results = Invoke-WebRequest -Uri $requestUri -Method POST -Headers $requestHeaders -Body $requestBody -UseBasicParsing;

$jsonResults = $results.Content | ConvertFrom-Json;
$wtsResults = $jsonResults.results[0].extensions | where {$_.extensionName -eq "WindowsTemplateStudio"} ;
$wtsFileUrl = $wtsResults.versions[0].files | where {$_.assetType -eq "Microsoft.Templates.2017.vsix"};

$wtsVsix = [System.IO.Path]::GetFileName($wtsFileUrl.source);
$wtsFullPath = [System.IO.Path]::Combine((Resolve-Path $env:USERPROFILE).path, $wtsVsix);

Invoke-WebRequest -Uri $wtsFileUrl.source -OutFile $wtsFullPath;

$vsixInstallerFile = Get-Childitem -Include vsixinstaller.exe -Recurse -Path "C:\Program Files (x86)\Microsoft Visual Studio\2017\";
$wtsArgList = "/quiet `"$wtsFullPath`"";

$vsixInstallerResult = Start-Process -FilePath $vsixInstallerFile.FullName -ArgumentList $wtsArgList -Wait -PassThru;

Remove-Item $wtsFullPath


#--- Uninstall unnecessary applications that come with Windows out of the box ---
Write-Host "Uninstall some applications that come with Windows out of the box" -ForegroundColor "Yellow"

#Referenced to build script
# https://docs.microsoft.com/en-us/windows/application-management/remove-provisioned-apps-during-update
# https://github.com/jayharris/dotfiles-windows/blob/master/windows.ps1#L157
# https://gist.github.com/jessfraz/7c319b046daa101a4aaef937a20ff41f
# https://gist.github.com/alirobe/7f3b34ad89a159e6daa1
# https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/scripts/remove-default-apps.ps1

function removeApp {
	Param ([string]$appName)
	Write-Output "Trying to remove $appName"
	Get-AppxPackage $appName -AllUsers | Remove-AppxPackage
	Get-AppXProvisionedPackage -Online | Where DisplayName -like $appName | Remove-AppxProvisionedPackage -Online
}

$applicationList = @(
	"Microsoft.MicrosoftEdge"
	"Microsoft.Office.OneNote"
	"Microsoft.SkypeApp"
	"Microsoft.BingFinance"
	"Microsoft.3DBuilder"
	"Microsoft.BingFinance"
	"Microsoft.BingNews"
	"Microsoft.BingSports"
	"Microsoft.BingWeather"
	"Microsoft.CommsPhone"
	"Microsoft.Getstarted"
	"Microsoft.WindowsMaps"
	"*MarchofEmpires*"
	"Microsoft.GetHelp"
	"Microsoft.Messaging"
	"*Minecraft*"
	"Microsoft.MicrosoftOfficeHub"
	"Microsoft.OneConnect"
	"Microsoft.WindowsPhone"
	"Microsoft.WindowsSoundRecorder"
	"*Solitaire*"
	"Microsoft.MicrosoftStickyNotes"
	"Microsoft.Office.Sway"
	"Microsoft.XboxApp"
	"Microsoft.XboxIdentityProvider"
	"Microsoft.ZuneMusic"
	"Microsoft.ZuneVideo"
	"Microsoft.NetworkSpeedTest"
	"Microsoft.FreshPaint"
	"Microsoft.Print3D"
	"*Autodesk*"
	"*BubbleWitch*"
    "king.com*"
    "G5*"
	"*Dell*"
	"*Facebook*"
	"*Keeper*"
	"*Netflix*"
	"*Twitter*"
	"*Plex*"
	"*.Duolingo-LearnLanguagesforFree"
	"*.EclipseManager"
	"ActiproSoftwareLLC.562882FEEB491" # Code Writer
	"*.AdobePhotoshopExpress"
);

foreach ($app in $applicationList) {
    removeApp $app
}


# -----------------------------------------------------------------------------

if (Check-Command -cmdname 'choco') {
    Write-Host "Choco is already installed, skip installation."
}
else {
    Write-Host ""
    Write-Host "Installing Chocolatey for Windows..." -ForegroundColor Green
    Write-Host "------------------------------------" -ForegroundColor Green
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host ""
Write-Host "Installing Applications..." -ForegroundColor Green
Write-Host "------------------------------------" -ForegroundColor Green

if (Check-Command -cmdname 'git') {
    Write-Host "Git is already installed, checking new version..."
    choco update git -y
}
else {
    Write-Host ""
    Write-Host "Installing Git for Windows..." -ForegroundColor Green
    choco install git -y
}

choco install 7zip.install -y
choco install googlechrome -y
choco install jetbrainstoolbox -y
choco install launchy -y
choco install slack -y
choco install docker-cli -y
choco install -y docker-for-windows
choco install vscode -y
choco install vscode-mssql -y
choco install linqpad -y
choco install vscode-powershell -y
choco install -y vscode-docker
choco install github-desktop -y
choco install visualstudio2019community -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"


Read-Host -Prompt "Setup finished, press [ENTER] to restart."
Restart-Computer