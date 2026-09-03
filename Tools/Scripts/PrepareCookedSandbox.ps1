param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$EngineRoot = $env:UE_ENGINE_ROOT,
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
$build = Join-Path $engine 'Engine\Build\BatchFiles\Build.bat'
$uat = Join-Path $engine 'Engine\Build\BatchFiles\RunUAT.bat'
$debugExe = Join-Path $root `
    'Binaries\Win64\RenderPipelineLab-Win64-Debug.exe'
$cookedRoot = Join-Path $root 'Saved\Cooked\Windows\RenderPipelineLab'

foreach ($path in @($project, $build, $uat)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file is missing: $path"
    }
}

& $build RenderPipelineLab Win64 Debug $project -WaitMutex
if ($LASTEXITCODE -ne 0) {
    throw "Debug Game Target build failed with exit code $LASTEXITCODE."
}

$cookArguments = @(Get-RenderPipelineCookArguments `
    -ProjectPath $project -Mode CookedSandbox -Iterative:$Iterative)
& $uat BuildCookRun @cookArguments
if ($LASTEXITCODE -ne 0) {
    throw "Cooked Sandbox preparation failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $debugExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $cookedRoot -PathType Container)) {
    throw 'Cooked Sandbox output is incomplete.'
}

$syncVsProfile = Join-Path $PSScriptRoot 'SyncVsDebugProfile.ps1'
$vsUserFile = Join-Path $root `
    'Intermediate\ProjectFiles\RenderPipelineLab.vcxproj.user'
if (Test-Path -LiteralPath $vsUserFile -PathType Leaf) {
    & $syncVsProfile -ProjectRoot $root `
        -Phase Phase1 -ShadowMode On -DebugMode ThreadBoundary
}
else {
    Write-Warning "VS user file is missing; regenerate project files and run SyncVsDebugProfile.ps1: $vsUserFile"
}

Write-Output "DebugExecutable=$debugExe"
Write-Output "CookedSandbox=$cookedRoot"
