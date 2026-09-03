$ErrorActionPreference = 'Stop'

$toolsRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = Split-Path $toolsRoot -Parent
$cases = @(
    @{
        File = 'PrepareCookedSandbox.bat'
        Expected = @('Tools\Scripts\PrepareCookedSandbox.ps1', '-Iterative')
    },
    @{
        File = 'StartCookedSandboxDebug.bat'
        Expected = @(
            'Tools\Scripts\StartCookedSandboxDebug.ps1',
            '-DebugMode ThreadBoundary',
            '-Phase Phase1',
            '-ShadowMode On'
        )
    },
    @{
        File = 'PrepareStagedDebug.bat'
        Expected = @('Tools\Scripts\PrepareStagedDebug.ps1')
    },
    @{
        File = 'StartStagedDebug.bat'
        Expected = @(
            'Tools\Scripts\StartStagedDebug.ps1',
            '-DebugMode ThreadBoundary',
            '-Phase Phase1',
            '-ShadowMode On',
            '-WaitForAttach'
        )
    },
    @{
        File = 'SyncVsDebugProfile.bat'
        Expected = @(
            'Tools\Scripts\SyncVsDebugProfile.ps1',
            '-DebugMode ThreadBoundary',
            '-Phase Phase1',
            '-ShadowMode On'
        )
    }
)

$previousDryRun = $env:RENDER_PIPELINE_DRY_RUN
$previousEngineRoot = $env:UE_ENGINE_ROOT
try {
    $env:RENDER_PIPELINE_DRY_RUN = '1'
    $env:UE_ENGINE_ROOT = 'C:\UE'

    foreach ($case in $cases) {
        $launcher = Join-Path $toolsRoot $case.File
        $output = (& $launcher 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "$($case.File) dry run failed with exit code $LASTEXITCODE."
        }
        foreach ($expected in $case.Expected) {
            if ($output -notlike "*$expected*") {
                throw "$($case.File) output is missing '$expected': $output"
            }
        }
    }

    $launchers = @(Get-ChildItem -LiteralPath $toolsRoot -File -Filter '*.bat')
    if ($launchers.Count -ne $cases.Count) {
        throw "Expected $($cases.Count) BAT launchers under Tools, found $($launchers.Count)."
    }
    $rootBatFiles = @(Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.bat')
    if ($rootBatFiles.Count -ne 0) {
        throw "BAT launchers must not remain at project root: $($rootBatFiles.Name -join ', ')"
    }
    $legacyLauncherRoot = Join-Path $toolsRoot 'Launchers'
    if (Test-Path -LiteralPath $legacyLauncherRoot) {
        throw "Legacy launcher directory must be removed: $legacyLauncherRoot"
    }
}
finally {
    $env:RENDER_PIPELINE_DRY_RUN = $previousDryRun
    $env:UE_ENGINE_ROOT = $previousEngineRoot
}

Write-Output 'Debug launcher tests passed.'
