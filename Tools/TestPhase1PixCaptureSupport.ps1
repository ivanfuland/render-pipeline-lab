param(
    [string]$SupportPath = (Join-Path $PSScriptRoot 'Phase1PixCaptureSupport.ps1')
)

$ErrorActionPreference = 'Stop'
. $SupportPath

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "RenderPipelineLab-Pix-$PID"
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe test root: $resolvedTemp"
}

try {
    New-Item -ItemType Directory -Path $resolvedTemp | Out-Null
    $capturePath = Join-Path $resolvedTemp 'capture.wpix'
    $writer = [IO.File]::Open(
        $capturePath,
        [IO.FileMode]::Create,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None)
    $writer.SetLength(2MB)

    $captureLog = 'PixWinPlugin: Capturing a frame in PIX'
    if (Test-Phase1PixCaptureComplete `
        -CapturePath $capturePath -LogContent $captureLog) {
        throw 'A capture with an active writer unexpectedly passed.'
    }

    $writer.Dispose()
    $writer = $null
    if (Test-Phase1PixCaptureComplete `
        -CapturePath $capturePath -LogContent 'Phase=Phase1 Stage=Ready') {
        throw 'A capture without the PIX capture log unexpectedly passed.'
    }
    if (-not (Test-Phase1PixCaptureComplete `
        -CapturePath $capturePath -LogContent $captureLog)) {
        throw 'A complete PIX capture failed validation.'
    }
}
finally {
    if ($writer) {
        $writer.Dispose()
    }
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Phase1 PIX capture support tests passed.'
