param(
    [Parameter(Mandatory = $true)]
    [string]$ShadowOnLog,
    [Parameter(Mandatory = $true)]
    [string]$ShadowOffLog
)

foreach ($path in @($ShadowOnLog, $ShadowOffLog)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Error "Phase1 log is missing: $path"
        exit 1
    }
}

$onLog = Get-Content -Raw -LiteralPath $ShadowOnLog
$offLog = Get-Content -Raw -LiteralPath $ShadowOffLog

if ($onLog -match 'Stage=(StartupFailed|ReadyFailed)' -or
    $offLog -match 'Stage=(StartupFailed|ReadyFailed)') {
    Write-Error 'A Phase1 run reported startup or readiness failure.'
    exit 1
}

foreach ($case in @(
    @{ Name = 'Shadow On'; Content = $onLog; Mode = 'On' },
    @{ Name = 'Shadow Off'; Content = $offLog; Mode = 'Off' }
)) {
    if ($case.Content -notmatch 'Phase=Phase1 Stage=Ready') {
        Write-Error "$($case.Name) did not reach Stage=Ready."
        exit 1
    }
    if ($case.Content -notmatch "Phase=Phase1 ShadowMode=$($case.Mode)\b") {
        Write-Error "$($case.Name) has the wrong ShadowMode."
        exit 1
    }
}

$targetPattern = 'Phase=Phase1 ShadowMode=(?<Mode>On|Off) TargetWorldPosition=(?<World>.+?) TargetScreenPosition=\((?<X>\d+),(?<Y>\d+)\) Viewport=(?<Width>\d+)x(?<Height>\d+)'
$onMatch = [regex]::Match($onLog, $targetPattern)
$offMatch = [regex]::Match($offLog, $targetPattern)
if (-not $onMatch.Success -or -not $offMatch.Success) {
    Write-Error 'Target world/screen position is missing.'
    exit 1
}

if ($onMatch.Groups['World'].Value -ne $offMatch.Groups['World'].Value) {
    Write-Error 'Target world position differs between runs.'
    exit 1
}
if ($onMatch.Groups['X'].Value -ne $offMatch.Groups['X'].Value -or
    $onMatch.Groups['Y'].Value -ne $offMatch.Groups['Y'].Value) {
    Write-Error 'Target screen position differs between runs.'
    exit 1
}
foreach ($match in @($onMatch, $offMatch)) {
    $width = [int]$match.Groups['Width'].Value
    $height = [int]$match.Groups['Height'].Value
    $x = [int]$match.Groups['X'].Value
    $y = [int]$match.Groups['Y'].Value
    if ($width -ne 1280 -or $height -ne 1080 -or
        $x -lt 0 -or $x -ge $width -or $y -lt 0 -or $y -ge $height) {
        Write-Error 'Target pixel or viewport is outside the Phase1 contract.'
        exit 1
    }
}

$requiredIntCVars = [ordered]@{
    'r.ForwardShading' = 0
    'r.UseClusteredDeferredShading_ToBeRemoved' = 0
    'r.Shadow.Virtual.Enable' = 0
    'r.Shadow.FilterMethod' = 0
    'r.Shadow.CacheWholeSceneShadows' = 0
    'r.Nanite.ProjectEnabled' = 0
    'r.Substrate' = 0
    'r.MegaLights.Allowed' = 0
    'r.RayTracing' = 0
    'r.DynamicGlobalIlluminationMethod' = 0
    'r.ReflectionMethod' = 0
    'r.GenerateMeshDistanceFields' = 0
    'r.AllowStaticLighting' = 0
    'sg.ViewDistanceQuality' = 3
    'sg.AntiAliasingQuality' = 3
    'sg.ShadowQuality' = 3
    'sg.GlobalIlluminationQuality' = 3
    'sg.ReflectionQuality' = 3
    'sg.PostProcessQuality' = 3
    'sg.TextureQuality' = 3
    'sg.EffectsQuality' = 3
    'sg.FoliageQuality' = 3
    'sg.ShadingQuality' = 3
    'sg.LandscapeQuality' = 3
}

foreach ($case in @(
    @{ Name = 'Shadow On'; Content = $onLog },
    @{ Name = 'Shadow Off'; Content = $offLog }
)) {
    foreach ($entry in $requiredIntCVars.GetEnumerator()) {
        $pattern = 'BaselineCVar Name=' + [regex]::Escape($entry.Key) +
            ' Value=' + $entry.Value + '\b'
        if ($case.Content -notmatch $pattern) {
            Write-Error "$($case.Name) is missing $($entry.Key)=$($entry.Value)."
            exit 1
        }
    }
}

$resolutionPattern = 'BaselineCVar Name=sg\.ResolutionQuality Value=(?<Value>\d+(?:\.\d+)?)'
$onResolutionMatch = [regex]::Match($onLog, $resolutionPattern)
$offResolutionMatch = [regex]::Match($offLog, $resolutionPattern)
if (-not $onResolutionMatch.Success -or -not $offResolutionMatch.Success) {
    Write-Error 'ResolutionQuality snapshot is missing.'
    exit 1
}
$onResolution = [float]::Parse(
    $onResolutionMatch.Groups['Value'].Value,
    [Globalization.CultureInfo]::InvariantCulture)
$offResolution = [float]::Parse(
    $offResolutionMatch.Groups['Value'].Value,
    [Globalization.CultureInfo]::InvariantCulture)
if ([Math]::Abs($onResolution - $offResolution) -gt 0.01) {
    Write-Error 'ResolutionQuality differs between runs.'
    exit 1
}
if ($onResolution -ne 0.0 -and
    ($onResolution -lt 10.0 -or $onResolution -gt 100.0)) {
    Write-Error 'ResolutionQuality is outside UE5.8.1 supported semantics.'
    exit 1
}

Write-Output (
    'Phase1 runtime verified. TargetWorld={0} TargetPixel=({1},{2})' -f
        $onMatch.Groups['World'].Value,
        $onMatch.Groups['X'].Value,
        $onMatch.Groups['Y'].Value)
