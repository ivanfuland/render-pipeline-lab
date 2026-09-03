param(
    [Parameter(Mandatory = $true)]
    [string]$ValidatorPath
)

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "RenderPipelineLab-Validator-$PID"
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe test root: $resolvedTemp"
}

function Invoke-ValidatorProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [switch]$RequireProjectLayout
    )

    $arguments = @('-NoProfile', '-File', $ValidatorPath, '-RepositoryRoot', $Root)
    if ($RequireProjectLayout) {
        $arguments += '-RequireProjectLayout'
    }

    $process = Start-Process -FilePath 'pwsh' -ArgumentList $arguments `
        -WindowStyle Hidden -Wait -PassThru
    return $process.ExitCode
}

try {
    New-Item -ItemType Directory -Path $resolvedTemp | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $resolvedTemp 'Source') | Out-Null
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'Source\Safe.cpp') `
        -Value 'int Safe = 1;'

    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -ne 0) {
        throw 'Safe fixture failed validation.'
    }

    New-Item -ItemType Directory -Path (Join-Path $resolvedTemp 'Saved\Captures') `
        -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'Saved\Captures\bad.wpix') `
        -Value 'capture'
    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -eq 0) {
        throw 'Capture fixture unexpectedly passed.'
    }

    Remove-Item -LiteralPath (Join-Path $resolvedTemp 'Saved') -Recurse -Force
    $unsafeAssignment = ('Security' + 'Token=DO_NOT_COMMIT')
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'DefaultEngine.ini') `
        -Value $unsafeAssignment
    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -eq 0) {
        throw 'Credential fixture unexpectedly passed.'
    }

    Remove-Item -LiteralPath (Join-Path $resolvedTemp 'DefaultEngine.ini') -Force
    $unsafeProject = @'
{
  "FileVersion": 3,
  "Plugins": [
    { "Name": "AndroidFileServer", "Enabled": true }
  ]
}
'@
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'Unsafe.uproject') `
        -Value $unsafeProject
    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -eq 0) {
        throw 'Enabled AndroidFileServer fixture unexpectedly passed.'
    }

    $layoutRoot = Join-Path $resolvedTemp 'LayoutFixture'
    $requiredLayoutPaths = @(
        'RenderPipelineLab.uproject',
        '.github/workflows/repository-checks.yml',
        'Source/RenderPipelineLab.Target.cs',
        'Source/RenderPipelineLabEditor.Target.cs',
        'Source/RenderPipelineLab/RenderPipelineLab.Build.cs',
        'Source/RenderPipelineLab/Core/RenderPipelinePhaseRegistry.cpp',
        'Source/RenderPipelineLab/Phases/Phase0_StaticBox/Phase0StaticBoxActor.cpp',
        'Source/RenderPipelineLab/Phases/Phase1_DirectLighting/Phase1DirectLightingActor.cpp'
    )

    New-Item -ItemType Directory -Path $layoutRoot | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $layoutRoot 'Source') | Out-Null
    if ((Invoke-ValidatorProcess -Root $layoutRoot -RequireProjectLayout) -eq 0) {
        throw 'Incomplete project layout unexpectedly passed.'
    }

    foreach ($relativePath in $requiredLayoutPaths) {
        $fullPath = Join-Path $layoutRoot $relativePath
        $parent = Split-Path -Parent $fullPath
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        if ($relativePath -eq 'RenderPipelineLab.uproject') {
            Set-Content -LiteralPath $fullPath -Value @'
{
  "FileVersion": 3,
  "Plugins": [
    { "Name": "AndroidFileServer", "Enabled": false }
  ]
}
'@
        }
        else {
            Set-Content -LiteralPath $fullPath -Value 'fixture'
        }
    }

    if ((Invoke-ValidatorProcess -Root $layoutRoot -RequireProjectLayout) -ne 0) {
        throw 'Complete project layout failed validation.'
    }
}
finally {
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Repository validator tests passed.'
