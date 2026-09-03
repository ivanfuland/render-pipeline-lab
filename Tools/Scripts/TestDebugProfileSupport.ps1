param(
    [string]$SupportPath = (Join-Path $PSScriptRoot 'DebugProfileSupport.ps1'),
    [string]$SyncPath = (Join-Path $PSScriptRoot 'SyncVsDebugProfile.ps1')
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
    -DebugMode ThreadBoundary `
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

Assert-Contains -Values $runArguments -Expected '-noperfthreads'
$threadBoundaryExecCmds = '-ExecCmds="r.Visibility.TaskSchedule 0,r.Visibility.DynamicMeshElements.NumMainViewTasks 0,r.MeshDrawCommands.ParallelPassSetup 0,r.ParallelBasePass 0,r.RHICmd.ParallelTranslate.Enable 0,r.OneFrameThreadLag 0,t.MaxFPS 5"'
Assert-Contains -Values $runArguments -Expected $threadBoundaryExecCmds
if ('-onethread' -in $runArguments -or '-norhithread' -in $runArguments) {
    throw 'ThreadBoundary unexpectedly disabled the Render/RHI thread topology.'
}

$controlFlowArguments = @(Get-RenderPipelineDebugArguments `
    -Phase Phase0 -ShadowMode On -DebugMode ControlFlow `
    -LogName 'CookedSandbox-Phase0-On.log')
Assert-Contains -Values $controlFlowArguments -Expected '-onethread'
Assert-Contains -Values $controlFlowArguments -Expected '-norhithread'
Assert-Contains -Values $controlFlowArguments `
    -Expected '-ExecCmds="t.MaxFPS 5"'
if ('-noperfthreads' -in $controlFlowArguments) {
    throw 'ControlFlow unexpectedly enabled the ThreadBoundary profile.'
}

$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$defaultEngine = Join-Path $projectRoot 'Config\DefaultEngine.ini'
$persistentDebugCVars = Select-String -LiteralPath $defaultEngine -Pattern @(
    '^r\.Visibility\.TaskSchedule=',
    '^r\.Visibility\.DynamicMeshElements\.NumMainViewTasks=',
    '^r\.MeshDrawCommands\.ParallelPassSetup=',
    '^r\.ParallelBasePass=',
    '^r\.RHICmd\.ParallelTranslate\.Enable=',
    '^r\.OneFrameThreadLag=',
    '^t\.MaxFPS='
)
if ($persistentDebugCVars) {
    throw "Debug-only CVars remain in DefaultEngine.ini: $($persistentDebugCVars.Line -join ', ')"
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
    New-Item -ItemType Directory -Path $resolvedTemp | Out-Null
    $vsUserFile = Join-Path $resolvedTemp 'RenderPipelineLab.vcxproj.user'
    @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="17.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
    <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
    <LocalDebuggerCommandArguments>old arguments</LocalDebuggerCommandArguments>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='DebugGame|x64'">
    <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
  </PropertyGroup>
</Project>
'@ | Set-Content -LiteralPath $vsUserFile -Encoding utf8

    & $SyncPath -ProjectRoot 'C:\Lab' -UserFilePath $vsUserFile `
        -Phase Phase1 -ShadowMode Off -DebugMode ThreadBoundary

    [xml]$vsUserDocument = Get-Content -Raw -LiteralPath $vsUserFile
    $namespace = New-Object System.Xml.XmlNamespaceManager(
        $vsUserDocument.NameTable)
    $namespace.AddNamespace('msb', $vsUserDocument.Project.NamespaceURI)
    $propertyGroups = $vsUserDocument.SelectNodes(
        '/msb:Project/msb:PropertyGroup', $namespace)
    $debugCondition = "'`$(Configuration)|`$(Platform)'=='Debug|x64'"
    $debugGroup = $propertyGroups |
        Where-Object { $_.Condition -eq $debugCondition } |
        Select-Object -First 1
    $expectedVsArguments = '-RenderPipelinePhase=Phase1 -dx12 -windowed -ResX=1280 -ResY=1080 -log -DefaultViewportMouseCaptureMode=NoCapture -Log=CookedSandbox-Phase1-Off.log -Phase1Shadow=Off -noperfthreads -ExecCmds="r.Visibility.TaskSchedule 0,r.Visibility.DynamicMeshElements.NumMainViewTasks 0,r.MeshDrawCommands.ParallelPassSetup 0,r.ParallelBasePass 0,r.RHICmd.ParallelTranslate.Enable 0,r.OneFrameThreadLag 0,t.MaxFPS 5"'
    if ($debugGroup.LocalDebuggerCommandArguments -ne $expectedVsArguments) {
        throw "VS Debug arguments were not synchronized: $($debugGroup.LocalDebuggerCommandArguments)"
    }
    $debugGameCondition = "'`$(Configuration)|`$(Platform)'=='DebugGame|x64'"
    $debugGameGroup = $propertyGroups |
        Where-Object { $_.Condition -eq $debugGameCondition } |
        Select-Object -First 1
    if ($debugGameGroup.DebuggerFlavor -ne 'WindowsLocalDebugger') {
        throw 'Sync unexpectedly changed the DebugGame property group.'
    }

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
