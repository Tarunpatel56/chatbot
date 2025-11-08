# Run this script as Administrator to allow port 8000 through Windows Firewall
# Right-click PowerShell and select "Run as Administrator", then run:
# .\allow_firewall.ps1

New-NetFirewallRule -DisplayName "FastAPI Backend Port 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow

Write-Host "Firewall rule added for port 8000" -ForegroundColor Green

