New-Item -ItemType Directory -Path ".\modules" -ErrorAction SilentlyContinue | Out-Null

@("https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psm1"
, "https://raw.githubusercontent.com/microsoft/Analysis-Services/master/pbidevmode/fabricps-pbip/FabricPS-PBIP.psd1") |% {

    Invoke-WebRequest -Uri $_ -OutFile ".\modules\$(Split-Path $_ -Leaf)"
}

if(-not (Get-Module Az.Accounts -ListAvailable)) { 
    Install-Module Az.Accounts -Scope CurrentUser -Force
}

Import-Module ".\modules\FabricPS-PBIP" -Force

Connect-AzAccount

$workspace = Get-FabricWorkspace -workspaceName 'capacity'

$semanticModelImport = Import-FabricItem -workspaceId $workspace.id -path ".\Sales & Returns Sample v201912.SemanticModel"

$semanticReportImport = Import-FabricItem -workspaceId $workspace.id -path ".\Sales & Returns Sample v201912.Report"`
 -itemProperties @{"semanticModelId" = $semanticModelImport.Id} 