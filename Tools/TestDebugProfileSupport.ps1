param(
    [string]$SupportPath = (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1')
)

$ErrorActionPreference = 'Stop'
. $SupportPath

function Assert-Contains {
    param(
        [string[]]$Values,
        [string]$Expected
    )

    if ($Expected -notin $Values) {
        throw "Missing expected argument: $Expected"
    }
}

$runArguments = @(Get-RenderPipelineDebugArguments `
    -Phase Phase1 -ShadowMode Off -WaitForAttach `
    -LogName 'StagedDebug-Phase1-Off.log')
foreach ($expected in @(
    '-RenderPipelinePhase=Phase1',
    '-Phase1Shadow=Off',
    '-dx12',
    '-windowed',
    '-ResX=1280',
    '-ResY=1080',
    '-DefaultViewportMouseCaptureMode=NoCapture',
    '-waitforattach',
    '-Log=StagedDebug-Phase1-Off.log'
)) {
    Assert-Contains -Values $runArguments -Expected $expected
}

$projectPath = 'C:\Lab\RenderPipelineLab.uproject'
$sandboxArguments = @(Get-RenderPipelineCookArguments `
    -ProjectPath $projectPath -Mode CookedSandbox -Iterative)
Assert-Contains -Values $sandboxArguments -Expected '-cook'
Assert-Contains -Values $sandboxArguments -Expected '-iterate'
if ('-stage' -in $sandboxArguments -or '-pak' -in $sandboxArguments -or
    '-archive' -in $sandboxArguments) {
    throw 'Cooked Sandbox unexpectedly contains Stage/Pak/Archive arguments.'
}

$stageArguments = @(Get-RenderPipelineCookArguments `
    -ProjectPath $projectPath -Mode StagedDebug `
    -ArchiveRoot 'C:\Lab\Saved\StagedDebug')
foreach ($expected in @(
    '-build', '-cook', '-stage', '-pak', '-archive',
    '-clientconfig=Debug',
    '-archivedirectory=C:\Lab\Saved\StagedDebug'
)) {
    Assert-Contains -Values $stageArguments -Expected $expected
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "RenderPipelineLab-Profiles-$PID"
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe test root: $resolvedTemp"
}

try {
    $binaryRoot = Join-Path $resolvedTemp 'RenderPipelineLab\Binaries\Win64'
    New-Item -ItemType Directory -Path $binaryRoot | Out-Null
    $plainExe = Join-Path $binaryRoot 'RenderPipelineLab.exe'
    $debugExe = Join-Path $binaryRoot 'RenderPipelineLab-Win64-Debug.exe'
    Set-Content -LiteralPath $plainExe -Value 'plain'
    Set-Content -LiteralPath $debugExe -Value 'debug'

    $resolvedExe = Resolve-RenderPipelineStagedDebugExecutable `
        -StageWindows $resolvedTemp
    if ($resolvedExe -ne $debugExe) {
        throw "Debug executable was not preferred: $resolvedExe"
    }
}
finally {
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Debug profile support tests passed.'
