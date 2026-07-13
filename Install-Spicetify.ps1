<#
.SYNOPSIS
    Automated installer for Spicetify CLI.
#>

[CmdletBinding()]
param()

if (-not $env:SPICETIFY_VISIBLE_RUN) {
    $env:SPICETIFY_VISIBLE_RUN = "1"
    Start-Process powershell.exe -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`""
    ) -WindowStyle Normal
    exit
}

$ErrorActionPreference = "Stop"

$Host.UI | Add-Member -MemberType ScriptMethod -Name PromptForChoice -Force -Value {
    param($caption, $message, $choices, $defaultChoice)
    Write-Host "$message" -ForegroundColor Cyan
    Write-Host "(auto-answered: Yes)" -ForegroundColor DarkGray
    return $defaultChoice
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

Write-Step "Checking PowerShell execution policy"
$currentPolicy = Get-ExecutionPolicy -Scope Process
if ($currentPolicy -eq "Restricted") {
    Write-Host "Setting process-scoped execution policy to Bypass (does not affect system settings)"
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

Write-Step "Checking for Spotify installation"
$spotifyPath = "$env:APPDATA\Spotify\Spotify.exe"
if (-not (Test-Path $spotifyPath)) {
    Write-Warning "Spotify does not appear to be installed at the default location ($spotifyPath)."
    Write-Warning "Spicetify requires Spotify to be installed first. Continuing anyway, but install may fail."
}

Write-Step "Closing Spotify if running"
Get-Process -Name "Spotify" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Step "Downloading and running official Spicetify installer"
try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spicetify/cli/main/install.ps1" -UseBasicParsing)
}
catch {
    Write-Error "Spicetify installation failed: $_"
    exit 1
}

Write-Step "Refreshing PATH for current session"
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$env:Path = "$machinePath;$userPath"

Write-Step "Verifying Spicetify installation"
if (Test-CommandExists "spicetify") {
    $version = spicetify -v
    Write-Host "Spicetify installed successfully. Version: $version" -ForegroundColor Green
}
else {
    Write-Warning "Spicetify command not found in this session. Try opening a new PowerShell window and running 'spicetify -v'."
}

Write-Step "Installing Spicetify Marketplace"
try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1" -UseBasicParsing)
    Write-Host "Marketplace install script executed." -ForegroundColor Green
}
catch {
    Write-Warning "Marketplace installation failed: $_"
}

Write-Step "Adding Spicetify auto-reapply to Startup folder"

$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath  = Join-Path $startupFolder "Spicetify AutoApply.lnk"
$spicetifyExe  = "$env:LOCALAPPDATA\spicetify\spicetify.exe"

try {
    $wshell   = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments  = "-NoExit -WindowStyle Normal -Command `"& '$spicetifyExe' apply`""
    $shortcut.WorkingDirectory = "$env:LOCALAPPDATA\spicetify"
    $shortcut.Description = "Reapplies Spicetify patches to Spotify on login"
    $shortcut.Save()

    Write-Host "Startup shortcut created at:" -ForegroundColor Green
    Write-Host "  $shortcutPath" -ForegroundColor Green
    Write-Host "A console window will show the reapply output on every login." -ForegroundColor Green
}
catch {
    Write-Warning "Could not create startup shortcut: $_"
    Write-Warning "You can reapply manually anytime with: spicetify apply"
}

Write-Step "Done"
Write-Host "If 'spicetify' isn't recognized, restart your terminal and run:" -ForegroundColor Yellow
Write-Host "  spicetify backup apply" -ForegroundColor Yellow
Write-Host "`nTo remove the auto-apply on login later, delete this file:" -ForegroundColor Yellow
Write-Host "  $shortcutPath" -ForegroundColor Yellow
Write-Host "`nThis window will stay open so you can review the output above." -ForegroundColor DarkGray
Read-Host "Press Enter to close"
