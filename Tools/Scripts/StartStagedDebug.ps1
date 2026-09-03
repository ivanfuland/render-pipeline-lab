param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$ArchiveRoot,
    [ValidateSet('Phase0', 'Phase1')]
    [string]$Phase = 'Phase0',
    [ValidateSet('On', 'Off')]
    [string]$ShadowMode = 'On',
    [ValidateSet('ControlFlow', 'ThreadBoundary')]
    [string]$DebugMode = 'ThreadBoundary',
    [switch]$WaitForAttach
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1')

$root = [IO.Path]::GetFullPath($ProjectRoot)
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    $ArchiveRoot = Join-Path $root 'Saved\StagedDebug'
}
$archive = [IO.Path]::GetFullPath($ArchiveRoot)
$stageWindows = Join-Path $archive 'Windows'
$exe = Resolve-RenderPipelineStagedDebugExecutable `
    -StageWindows $stageWindows
$logRoot = Join-Path $stageWindows 'RenderPipelineLab\Saved\Logs'
$logName = "StagedDebug-$Phase-$ShadowMode.log"
$log = Join-Path $logRoot $logName
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$arguments = @(Get-RenderPipelineDebugArguments `
    -Phase $Phase -ShadowMode $ShadowMode -LogName $logName `
    -DebugMode $DebugMode `
    -WaitForAttach:$WaitForAttach)
$process = Start-Process -FilePath $exe -WorkingDirectory $stageWindows `
    -ArgumentList $arguments -WindowStyle Normal -PassThru

Write-Output "Profile=StagedDebug"
Write-Output "DebugMode=$DebugMode"
Write-Output "ProcessId=$($process.Id)"
Write-Output "Executable=$exe"
Write-Output "ContentRoot=$stageWindows"
Write-Output "Log=$log"
