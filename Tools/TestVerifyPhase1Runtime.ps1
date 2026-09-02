param(
    [Parameter(Mandatory = $true)]
    [string]$VerifierPath
)

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "RenderPipelineLab-Phase1Verifier-$PID"
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe test root: $resolvedTemp"
}

function New-Phase1Log {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet('On', 'Off')][string]$Mode,
        [int]$TargetX = 640,
        [float]$ResolutionQuality = 100.0
    )

    $required = @(
        'r.ForwardShading=0',
        'r.UseClusteredDeferredShading_ToBeRemoved=0',
        'r.Shadow.Virtual.Enable=0',
        'r.Shadow.FilterMethod=0',
        'r.Shadow.CacheWholeSceneShadows=0',
        'r.Nanite.ProjectEnabled=0',
        'r.Substrate=0',
        'r.MegaLights.Allowed=0',
        'r.RayTracing=0',
        'r.DynamicGlobalIlluminationMethod=0',
        'r.ReflectionMethod=0',
        'r.GenerateMeshDistanceFields=0',
        'r.AllowStaticLighting=0',
        'sg.ViewDistanceQuality=3',
        'sg.AntiAliasingQuality=3',
        'sg.ShadowQuality=3',
        'sg.GlobalIlluminationQuality=3',
        'sg.ReflectionQuality=3',
        'sg.PostProcessQuality=3',
        'sg.TextureQuality=3',
        'sg.EffectsQuality=3',
        'sg.FoliageQuality=3',
        'sg.ShadingQuality=3',
        'sg.LandscapeQuality=3'
    )

    $lines = [Collections.Generic.List[string]]::new()
    foreach ($entry in $required) {
        $parts = $entry.Split('=')
        $lines.Add("Phase=Phase1 BaselineCVar Name=$($parts[0]) Value=$($parts[1])")
    }
    $lines.Add("Phase=Phase1 BaselineCVar Name=sg.ResolutionQuality Value=$($ResolutionQuality.ToString('F2', [Globalization.CultureInfo]::InvariantCulture)) Expected=RecordOnly")
    $lines.Add("Phase=Phase1 ShadowMode=$Mode TargetWorldPosition=X=50.000 Y=0.000 Z=1.000 TargetScreenPosition=($TargetX,540) Viewport=1280x1080 FeatureLevel=6")
    $lines.Add('Phase=Phase1 Stage=Ready')
    Set-Content -LiteralPath $Path -Value $lines
}

function Invoke-Verifier {
    param([string]$OnLog, [string]$OffLog)
    $resolvedVerifier = [IO.Path]::GetFullPath($VerifierPath)
    $arguments = @(
        '-NoProfile', '-File', $resolvedVerifier,
        '-ShadowOnLog', $OnLog,
        '-ShadowOffLog', $OffLog
    )
    & pwsh @arguments | Out-Host
    $exitCode = $LASTEXITCODE
    Write-Host "VerifierExit=$exitCode"
    return $exitCode
}

try {
    New-Item -ItemType Directory -Path $resolvedTemp | Out-Null
    $onLog = Join-Path $resolvedTemp 'On.log'
    $offLog = Join-Path $resolvedTemp 'Off.log'
    New-Phase1Log -Path $onLog -Mode On
    New-Phase1Log -Path $offLog -Mode Off
    if ((Invoke-Verifier -OnLog $onLog -OffLog $offLog) -ne 0) {
        throw 'Matching Phase1 logs failed verification.'
    }

    New-Phase1Log -Path $onLog -Mode On -ResolutionQuality 0
    New-Phase1Log -Path $offLog -Mode Off -ResolutionQuality 0
    if ((Invoke-Verifier -OnLog $onLog -OffLog $offLog) -ne 0) {
        throw 'Matching project-default ResolutionQuality logs failed verification.'
    }

    New-Phase1Log -Path $offLog -Mode Off -TargetX 641
    if ((Invoke-Verifier -OnLog $onLog -OffLog $offLog) -eq 0) {
        throw 'Mismatched target coordinates unexpectedly passed.'
    }
}
finally {
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Phase1 runtime verifier tests passed.'
