param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [ValidateSet('Phase0', 'Phase1')]
    [string]$Phase = 'Phase0',
    [ValidateSet('On', 'Off')]
    [string]$ShadowMode = 'On',
    [switch]$WaitForAttach
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1')

$root = [IO.Path]::GetFullPath($ProjectRoot)
$exe = Join-Path $root 'Binaries\Win64\RenderPipelineLab-Win64-Debug.exe'
$cookedRoot = Join-Path $root 'Saved\Cooked\Windows\RenderPipelineLab'
$logRoot = Join-Path $cookedRoot 'Saved\Logs'
$logName = "CookedSandbox-$Phase-$ShadowMode.log"
$log = Join-Path $logRoot $logName

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Debug executable is missing: $exe"
}
if (-not (Test-Path -LiteralPath $cookedRoot -PathType Container)) {
    throw "Cooked Sandbox is missing: $cookedRoot"
}
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$arguments = @(Get-RenderPipelineDebugArguments `
    -Phase $Phase -ShadowMode $ShadowMode -LogName $logName `
    -WaitForAttach:$WaitForAttach)
$process = Start-Process -FilePath $exe -WorkingDirectory $root `
    -ArgumentList $arguments -WindowStyle Normal -PassThru

Write-Output "Profile=CookedSandbox"
Write-Output "ProcessId=$($process.Id)"
Write-Output "Executable=$exe"
Write-Output "ContentRoot=$cookedRoot"
Write-Output "Log=$log"
