#requires -Version 7

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Write-Host "Loading Module Assemblies"

$libraryPath = "C:\@Repos\Github\tmdl-sample\Libs"

$nugets = @(
    @{
        name = "Microsoft.AnalysisServices.NetCore.retail.amd64"
        ;
        version = "19.84.1"
        ;
        path = @("lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.dll"
        , "lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.Json.dll"
        , "lib\netcoreapp3.0\Microsoft.AnalysisServices.Runtime.Windows.dll"
        )
    }
    # There is a bug with this package, need to manual download and place it on the Nuget folder
    ,
    @{
        name = "Microsoft.AnalysisServices.Tabular.Tmdl.NetCore.retail.amd64"
        ;
        version = "19.69.6.2-TmdlPreview"
        ;
        path = @("lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.Tmdl.dll")
    }
    ,
    @{
        name = "Microsoft.Identity.Client"
        ;
        version = "4.56.0"
        ;
        path = @("lib\netcoreapp2.1\Microsoft.Identity.Client.dll")
    }
    ,
    @{
        name = "Microsoft.IdentityModel.Abstractions"
        ;
        version = "6.22.0"
        ;
        path = @("lib\netstandard2.0\Microsoft.IdentityModel.Abstractions.dll")
    }
)

foreach ($nuget in $nugets)
{
    Write-Host "Installing nuget: $($nuget.name)"

    if (!(Test-Path "$currentPath\Nuget\$($nuget.name).$($nuget.Version)" -PathType Container)) {
        Install-Package -Name $nuget.name -ProviderName NuGet -Destination "$currentPath\Nuget" -RequiredVersion $nuget.Version -SkipDependencies -AllowPrereleaseVersions -Scope CurrentUser  -Force
    }
    
    foreach ($nugetPath in $nuget.path)
    {
        $path = Resolve-Path (Join-Path "$currentPath\Nuget\$($nuget.name).$($nuget.Version)" $nugetPath)
        Add-Type -Path $path -Verbose | Out-Null
    }
   
}

Function ConvertTo-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmslPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$outputPath
	)

    Write-Host "Read TMSL"

    $tmslText = Get-Content $tmslPath

    $database = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($tmslText)

    Write-Host "Serialize to TMDL"

    [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeModelToFolder($database.Model, $outputPath)
}

Function ConvertFrom-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmdlPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$outputPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$databaseName
	)

    Write-Host "Read TMDL"

    $model = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeModelFromFolder($tmdlPath)

    Write-Host "Serialize to TMSL"

    $options = New-Object Microsoft.AnalysisServices.Tabular.SerializeOptions

    $options.SplitMultilineStrings = $true

    $database = New-Object Microsoft.AnalysisServices.Tabular.Database
    $database.Model = $model
    $database.Name = $databaseName
    
    $tmslText = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($database,$options)

    $tmslText | Out-File -FilePath $outputPath -Encoding UTF8
}

Function Publish-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmdlPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$serverConnection
        ,
        [Parameter(Mandatory = $true)]
        [string]$datasetName
	)

    Write-Host "Read TMDL"

    $model = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeModelFromFolder($tmdlPath)

    try {
        Write-Host "Connecting to server"
        $server = New-Object Microsoft.AnalysisServices.Tabular.Server

        $server.Connect($serverConnection)

        $remoteDatabase = $server.Databases.FindByName($datasetName)

        if ($remoteDatabase)
        {
            Write-Host "Updating dataset '$datasetName'"

            $model.CopyTo($remoteDatabase.Model)

            $remoteDatabase.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)

            $result = $remoteDatabase.Model.SaveChanges()

            Write-Host "Dataset '$datasetName' updated successfully"
        }
        else {
            Write-Host "Creating new dataset '$datasetName'"

            $model.Name = $datasetName

            $remoteDatabase = New-Object Microsoft.AnalysisServices.Tabular.Database
            $remoteDatabase.Name = $datasetName
            $remoteDatabase.Model = $model

            $server.Databases.Add($remoteDatabase)

            $remoteDatabase.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
        }
    }
    catch [System.Exception] {
        Write-Host "Exception details: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Host "Inner exception: $($_.Exception.InnerException.Message)"
        }
        throw
    }
    finally {
        if ($remoteDatabase)
        {
            $remoteDatabase.Dispose()
        }

        if ($server)
        {
            $server.Dispose()
        }
    }

    
}