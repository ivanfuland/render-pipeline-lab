param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$EngineRoot = $env:UE_ENGINE_ROOT,
    [string]$ArchiveRoot,
    [switch]$Iterative
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1')

if ([string]::IsNullOrWhiteSpace($EngineRoot)) {
    throw 'EngineRoot is required; pass -EngineRoot or set UE_ENGINE_ROOT.'
}
$root = [IO.Path]::GetFullPath($ProjectRoot)
$engine = [IO.Path]::GetFullPath($EngineRoot)
$project = Join-Path $root 'RenderPipelineLab.uproject'
$uat = Join-Path $engine 'Engine\Build\BatchFiles\RunUAT.bat'
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    $ArchiveRoot = Join-Path $root 'Saved\StagedDebug'
}
$archive = [IO.Path]::GetFullPath($ArchiveRoot)
$stageWindows = Join-Path $archive 'Windows'

foreach ($path in @($project, $uat)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file is missing: $path"
    }
}

$cookArguments = @(Get-RenderPipelineCookArguments `
    -ProjectPath $project -Mode StagedDebug `
    -ArchiveRoot $archive -Iterative:$Iterative)
& $uat BuildCookRun @cookArguments
if ($LASTEXITCODE -ne 0) {
    throw "Staged Debug preparation failed with exit code $LASTEXITCODE."
}

$stagedExe = Resolve-RenderPipelineStagedDebugExecutable `
    -StageWindows $stageWindows
Write-Output "StagedDebug=$stageWindows"
Write-Output "DebugExecutable=$stagedExe"
