function Get-RenderPipelineDebugArguments {
    param(
        [ValidateSet('Phase0', 'Phase1')]
        [string]$Phase = 'Phase0',
        [ValidateSet('On', 'Off')]
        [string]$ShadowMode = 'On',
        [ValidateSet('ControlFlow', 'ThreadBoundary')]
        [string]$DebugMode = 'ThreadBoundary',
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        [switch]$WaitForAttach
    )

    $arguments = @(
        "-RenderPipelinePhase=$Phase",
        '-dx12',
        '-windowed',
        '-ResX=1280',
        '-ResY=1080',
        '-log',
        '-DefaultViewportMouseCaptureMode=NoCapture',
        "-Log=$LogName"
    )
    if ($Phase -eq 'Phase1') {
        $arguments += "-Phase1Shadow=$ShadowMode"
    }
    if ($WaitForAttach) {
        $arguments += '-waitforattach'
    }
    if ($DebugMode -eq 'ControlFlow') {
        $arguments += @(
            '-onethread',
            '-norhithread',
            '-ExecCmds="t.MaxFPS 5"'
        )
    }
    else {
        $arguments += @(
            '-noperfthreads',
            '-ExecCmds="r.Visibility.TaskSchedule 0,r.Visibility.DynamicMeshElements.NumMainViewTasks 0,r.MeshDrawCommands.ParallelPassSetup 0,r.ParallelBasePass 0,r.RHICmd.ParallelTranslate.Enable 0,r.OneFrameThreadLag 0,t.MaxFPS 5"'
        )
    }
    return $arguments
}

function Get-RenderPipelineCookArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [ValidateSet('CookedSandbox', 'StagedDebug')]
        [string]$Mode,
        [string]$ArchiveRoot,
        [switch]$Iterative
    )

    $arguments = @(
        "-project=$ProjectPath",
        '-noP4',
        '-platform=Win64',
        '-clientconfig=Debug',
        '-target=RenderPipelineLab',
        '-cook',
        '-map=/Engine/Maps/Entry',
        '-utf8output'
    )
    if ($Iterative) {
        $arguments += '-iterate'
    }
    if ($Mode -eq 'StagedDebug') {
        if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
            throw 'ArchiveRoot is required for StagedDebug.'
        }
        $arguments += @(
            '-build',
            '-stage',
            '-pak',
            '-archive',
            "-archivedirectory=$ArchiveRoot"
        )
    }
    return $arguments
}

function Resolve-RenderPipelineStagedDebugExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StageWindows
    )

    $resolvedStage = [IO.Path]::GetFullPath($StageWindows)
    if (-not (Test-Path -LiteralPath $resolvedStage -PathType Container)) {
        throw "Staged Windows directory is missing: $resolvedStage"
    }

    $debugExecutables = @(Get-ChildItem -LiteralPath $resolvedStage -Recurse `
        -File -Filter 'RenderPipelineLab-Win64-Debug.exe')
    if ($debugExecutables.Count -eq 1) {
        return $debugExecutables[0].FullName
    }
    if ($debugExecutables.Count -gt 1) {
        throw "Multiple staged Debug executables found under: $resolvedStage"
    }

    $plainExecutables = @(Get-ChildItem -LiteralPath $resolvedStage -Recurse `
        -File -Filter 'RenderPipelineLab.exe')
    if ($plainExecutables.Count -eq 1) {
        return $plainExecutables[0].FullName
    }
    throw "Exactly one staged Debug executable was expected under: $resolvedStage"
}
