# Windows Setup Script for Ollama and Open WebUI
# Save this as setup-ai-environment.ps1

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "    Ollama and Open WebUI Setup Script for Windows" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Check for administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script needs to be run as Administrator. Trying to restart with admin rights..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Create directories
Write-Host "Creating necessary directories..." -ForegroundColor Green
$dataDir = "C:\open-webui\data"
$ollamaDir = "C:\Ollama"

if (!(Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}
if (!(Test-Path $ollamaDir)) {
    New-Item -ItemType Directory -Path $ollamaDir -Force | Out-Null
}

# Install Python if it's not already installed
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Python not found. Installing Python 3.11..." -ForegroundColor Yellow
    
    # Download Python 3.11
    $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-3.11.8-amd64.exe"
    
    Write-Host "Downloading Python 3.11..." -ForegroundColor Green
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    
    # Install Python (silently, with pip, add to PATH)
    Write-Host "Installing Python 3.11..." -ForegroundColor Green
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_pip=1" -Wait
    
    # Remove installer
    Remove-Item $pythonInstaller
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Python 3.11 has been installed." -ForegroundColor Green
} else {
    Write-Host "Python is already installed." -ForegroundColor Green
}

# Install uv package manager
Write-Host "Installing the uv package manager..." -ForegroundColor Green
Invoke-Expression "powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""

# Refresh environment variables again to include uv
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Download and install Ollama
Write-Host "Downloading and installing Ollama..." -ForegroundColor Green
$ollamaUrl = "https://ollama.com/download/ollama-windows-amd64.zip"
$ollamaZip = "$env:TEMP\ollama-windows.zip"

Invoke-WebRequest -Uri $ollamaUrl -OutFile $ollamaZip
Expand-Archive -Path $ollamaZip -DestinationPath $ollamaDir -Force
Remove-Item $ollamaZip

# Add Ollama to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$ollamaDir*") {
    [Environment]::SetEnvironmentVariable("Path", $currentPath + ";$ollamaDir", "Machine")
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "Ollama has been installed to $ollamaDir" -ForegroundColor Green

# Create a startup script for Open WebUI
$startupScriptPath = "$env:USERPROFILE\Desktop\Start-AI-Environment.ps1"
$startupScriptContent = @"
# Startup script for Ollama and Open WebUI
# Run this script whenever you want to use Ollama with Open WebUI

Write-Host "Starting Ollama service..." -ForegroundColor Green
Start-Process -FilePath "C:\Ollama\ollama.exe" -ArgumentList "serve" -WindowStyle Hidden

Write-Host "Waiting for Ollama to initialize (10 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "Starting Open WebUI..." -ForegroundColor Green
`$env:DATA_DIR="C:\open-webui\data"
uvx --python 3.11 open-webui@latest serve

# Note: This window will close when you exit Open WebUI
"@

Set-Content -Path $startupScriptPath -Value $startupScriptContent

# Create a shortcut on the desktop
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Start AI Environment.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$startupScriptPath`""
$Shortcut.Save()

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To start Ollama and Open WebUI:" -ForegroundColor Yellow
Write-Host "1. Double-click the 'Start AI Environment' shortcut on your desktop" -ForegroundColor Yellow
Write-Host "2. Once started, access Open WebUI at http://localhost:8080" -ForegroundColor Yellow
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")