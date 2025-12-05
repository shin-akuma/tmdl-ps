#requires -Version 7

<#
.SYNOPSIS
    Sample script demonstrating TMDL/TMSL conversion and Fabric deployment capabilities.

.DESCRIPTION
    This script provides examples for:
    - Converting TMSL (model.bim) to TMDL format
    - Converting TMDL back to TMSL format
    - Publishing semantic models via XMLA endpoint
    - Deploying semantic models and reports via Fabric REST API

.NOTES
    Prerequisites:
    - PowerShell 7 or later
    - Az.Accounts module for Azure authentication
    - Internet access to download FabricPS-PBIP module (if not already present)
#>

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)
Set-Location $currentPath

#region Module Setup

# Download and setup FabricPS-PBIP module if not present
New-Item -ItemType Directory -Path ".\modules" -ErrorAction SilentlyContinue | Out-Null

$fabricModulePath = ".\modules\FabricPS-PBIP.psm1"
if (-not (Test-Path $fabricModulePath)) {
    Write-Host "Downloading FabricPS-PBIP module..."
    @(
        "https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1",
        "https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psd1"
    ) | ForEach-Object {
        Invoke-WebRequest -Uri $_ -OutFile ".\modules\$(Split-Path $_ -Leaf)"
    }
}

# Install Az.Accounts module if not available
if (-not (Get-Module Az.Accounts -ListAvailable)) {
    Write-Host "Installing Az.Accounts module..."
    Install-Module Az.Accounts -Scope CurrentUser -Force
}

# Import required modules
Import-Module ".\TMDLPS.psm1" -Force
Import-Module ".\modules\FabricPS-PBIP" -Force

#endregion

#region Configuration

# Configuration variables - update these for your environment
$workspaceName = "capacity"
$semanticModelPath = ".\Sales & Returns Sample v201912.SemanticModel"
$reportPath = ".\Sales & Returns Sample v201912.Report"
$serverConnection = "powerbi://api.powerbi.com/v1.0/myorg/$workspaceName"
$datasetName = "Sales & Returns Sample"

#endregion

#region TMDL Conversion Examples

try {
    Write-Host "`n=== TMDL Conversion Examples ===" -ForegroundColor Cyan

    # Example 1: Convert TMSL (model.bim) to TMDL format
    Write-Host "`nConverting TMSL to TMDL..."
    ConvertTo-TMDL -tmslPath ".\Sales.bim" -outputPath ".\output\Sales"
    Write-Host "TMDL output saved to: .\output\Sales" -ForegroundColor Green

    # Example 2: Convert TMDL back to TMSL format
    Write-Host "`nConverting TMDL back to TMSL..."
    ConvertFrom-TMDL -tmdlPath ".\output\Sales" -outputPath ".\Sales_updated.bim" -databaseName "Sales"
    Write-Host "TMSL output saved to: .\Sales_updated.bim" -ForegroundColor Green
}
catch {
    Write-Host "TMDL Conversion Error: $($_.Exception.Message)" -ForegroundColor Red
}

#endregion

#region XMLA Endpoint Deployment Example

try {
    Write-Host "`n=== XMLA Endpoint Deployment ===" -ForegroundColor Cyan
    Write-Host "Publishing semantic model via XMLA endpoint..."
    
    # Publish using XMLA endpoint (requires proper authentication)
    # Uncomment the following lines to enable XMLA deployment:
    # Publish-TMDL -tmdlPath "$semanticModelPath\definition" `
    #     -serverConnection $serverConnection `
    #     -datasetName $datasetName
    
    Write-Host "XMLA deployment example is commented out. Uncomment to enable." -ForegroundColor Yellow
}
catch {
    Write-Host "XMLA Deployment Error: $($_.Exception.Message)" -ForegroundColor Red
}

#endregion

#region Fabric REST API Deployment Example

try {
    Write-Host "`n=== Fabric REST API Deployment ===" -ForegroundColor Cyan
    
    # Authenticate to Azure (interactive login)
    Write-Host "Connecting to Azure..."
    Connect-AzAccount
    
    # Get the target workspace
    Write-Host "Getting workspace: $workspaceName"
    $workspace = Get-FabricWorkspace -workspaceName $workspaceName
    Write-Host "Workspace ID: $($workspace.id)" -ForegroundColor Green
    
    # Import semantic model
    Write-Host "`nImporting semantic model from: $semanticModelPath"
    $semanticModelImport = Import-FabricItem -workspaceId $workspace.id -path $semanticModelPath
    Write-Host "Semantic model imported with ID: $($semanticModelImport.Id)" -ForegroundColor Green
    
    # Import report with reference to the semantic model
    Write-Host "`nImporting report from: $reportPath"
    $reportImport = Import-FabricItem -workspaceId $workspace.id -path $reportPath `
        -itemProperties @{ "semanticModelId" = $semanticModelImport.Id }
    Write-Host "Report imported with ID: $($reportImport.Id)" -ForegroundColor Green
    
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Fabric API Deployment Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
}

#endregion