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
}
finally {
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Repository validator tests passed.'
