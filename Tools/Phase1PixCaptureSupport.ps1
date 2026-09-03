function Test-Phase1PixCaptureComplete {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CapturePath,
        [Parameter(Mandatory = $true)]
        [string]$LogContent,
        [int64]$MinimumCaptureBytes = 1MB
    )

    if ($LogContent -notmatch 'PixWinPlugin: Capturing a frame in PIX' -or
        -not (Test-Path -LiteralPath $CapturePath -PathType Leaf)) {
        return $false
    }

    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $CapturePath,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::None)
        return $stream.Length -ge $MinimumCaptureBytes
    }
    catch [IO.IOException] {
        return $false
    }
    finally {
        if ($stream) {
            $stream.Dispose()
        }
    }
}
