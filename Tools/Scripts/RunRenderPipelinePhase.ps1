param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$EngineRoot = $env:UE_ENGINE_ROOT,
    [ValidateSet('Phase0', 'Phase1')]
    [string]$Phase = 'Phase0',
    [ValidateSet('On', 'Off')]
    [string]$ShadowMode = 'On',
    [switch]$Visible,
    [string]$LogName = 'RenderPipelinePhase.log'
)

if ([string]::IsNullOrWhiteSpace($EngineRoot)) {
    throw 'EngineRoot is required; pass -EngineRoot or set UE_ENGINE_ROOT.'
}

$project = Join-Path $ProjectRoot 'RenderPipelineLab.uproject'
$editor = Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor.exe'
if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
    throw "Project is missing: $project"
}
if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    throw "UnrealEditor is missing: $editor"
}
if ([IO.Path]::GetFileName($LogName) -ne $LogName) {
    throw 'LogName must be a file name without directory components.'
}

$arguments = @(
    $project,
    '-game',
    '-dx12',
    '-windowed',
    '-ResX=1280',
    '-ResY=1080',
    "-RenderPipelinePhase=$Phase",
    '-log',
    "-Log=$LogName"
)
if ($Phase -eq 'Phase1') {
    $arguments += "-Phase1Shadow=$ShadowMode"
}

$windowStyle = if ($Visible) { 'Normal' } else { 'Hidden' }
$process = Start-Process -FilePath $editor -ArgumentList $arguments `
    -WindowStyle $windowStyle -PassThru

Write-Output "ProcessId=$($process.Id)"
Write-Output "LogPath=$(Join-Path $ProjectRoot "Saved\Logs\$LogName")"
