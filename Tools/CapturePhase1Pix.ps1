param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [int]$TimeoutSeconds = 60
)

$stageWindows = Join-Path $ProjectRoot 'Saved\StagedPIX\Windows'
$exe = Join-Path $stageWindows `
    'RenderPipelineLab\Binaries\Win64\RenderPipelineLab.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Current staged executable is missing: $exe"
}

$sourceCaptureRoot = Join-Path $stageWindows `
    'RenderPipelineLab\Saved\PixCaptures'
$captureRoot = Join-Path $ProjectRoot 'Saved\Captures\PIX'
$logRoot = Join-Path $ProjectRoot 'Saved\Logs'
New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

foreach ($mode in @('On', 'Off')) {
    $destination = Join-Path $captureRoot "Phase1_Shadow$mode.wpix"
    if (Test-Path -LiteralPath $destination) {
        throw "Capture already exists; preserve or remove it explicitly: $destination"
    }

    $existingCapturePaths = @{}
    if (Test-Path -LiteralPath $sourceCaptureRoot) {
        Get-ChildItem -LiteralPath $sourceCaptureRoot -File -Filter '*.wpix' |
            ForEach-Object { $existingCapturePaths[$_.FullName] = $true }
    }

    $log = Join-Path $logRoot "Phase1SelfPix$mode.log"
    $process = Start-Process -FilePath $exe -WorkingDirectory $stageWindows `
        -ArgumentList @(
            '-dx12', '-windowed', '-ResX=1280', '-ResY=1080',
            '-RenderPipelinePhase=Phase1', "-Phase1Shadow=$mode",
            '-attachPIX', '-pixautocapture', '-log', "-AbsLog=$log"
        ) `
        -WindowStyle Hidden -PassThru

    $newCapture = $null
    try {
        $iterations = [Math]::Max(1, $TimeoutSeconds * 2)
        for ($index = 0; $index -lt $iterations; ++$index) {
            if (Test-Path -LiteralPath $sourceCaptureRoot) {
                $newCapture = Get-ChildItem -LiteralPath $sourceCaptureRoot `
                    -File -Filter '*.wpix' |
                    Where-Object { -not $existingCapturePaths.ContainsKey($_.FullName) } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
            }
            if ($newCapture) {
                break
            }
            if ($process.HasExited) {
                break
            }
            Start-Sleep -Milliseconds 500
        }
    }
    finally {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $newCapture) {
        throw "UE PixWinPlugin did not create a capture for Shadow $mode."
    }
    $logContent = Get-Content -Raw -LiteralPath $log
    if ($logContent -notmatch "Phase=Phase1 ShadowMode=$mode\b" -or
        $logContent -notmatch 'Phase=Phase1 Stage=Ready' -or
        $logContent -notmatch 'PixWinPlugin: Capturing a frame in PIX') {
        throw "Shadow $mode capture log did not satisfy the Phase1 contract."
    }

    Move-Item -LiteralPath $newCapture.FullName -Destination $destination
    Write-Output "Captured Shadow ${mode}: $destination"
}
