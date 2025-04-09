$ErrorActionPreference = "Continue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module ".\TMDLPS.psm1" -Force

try {

    ConvertTo-TMDL -tmslPath ".\Sales.bim" -outputPath ".\output\Sales"
    ConvertFrom-TMDL -tmdlPath ".\output\Sales" -outputPath ".\Sales_updated.bim" -databaseName "Sales"
    Publish-TMDL -tmdlPath ".\output\Sales" -serverConnection "powerbi://api.powerbi.com/v1.0/myorg/capacity" -datasetName "Sales"
    #Publish-TMDL -tmdlPath ".\Sales & Returns Sample v201912.SemanticModel\definition" -serverConnection "powerbi://api.powerbi.com/v1.0/myorg/capacity" -datasetName "Sales & Returns Sample"
}
catch {
    $ex = $_.Exception
    Write-Host $ex.ToString()
    
}