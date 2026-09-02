param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$LogPath
)

$engineIni = Join-Path $ProjectRoot 'Config\DefaultEngine.ini'
$content = Get-Content -Raw -LiteralPath $engineIni
$requiredSettings = @(
    'r.ForwardShading=False',
    'r.Nanite.ProjectEnabled=False',
    'r.DynamicGlobalIlluminationMethod=0',
    'r.ReflectionMethod=0',
    'r.RayTracing=False',
    'r.RayTracing.RayTracingProxies.ProjectEnabled=False',
    'r.Substrate=False',
    'r.Shadow.Virtual.Enable=0',
    'r.DefaultFeature.AutoExposure=False',
    'r.DefaultFeature.Bloom=False',
    'r.AllowStaticLighting=False',
    'r.GenerateMeshDistanceFields=False',
    'DefaultGraphicsRHI=DefaultGraphicsRHI_DX12',
    '+D3D12TargetedShaderFormats=PCD3D_SM6',
    'GameDefaultMap=/Engine/Maps/Entry',
    'GlobalDefaultGameMode=/Script/test.RenderPipelineProbeGameMode'
)

$missing = $requiredSettings | Where-Object { $content -notmatch [regex]::Escape($_) }
if ($missing.Count -gt 0)
{
    $missing | ForEach-Object { Write-Error "Missing baseline setting: $_" }
    exit 1
}

if ($LogPath)
{
    $log = Get-Content -Raw -LiteralPath $LogPath
    foreach ($pattern in @('Using Forced RHI: D3D12', 'PCD3D_SM6', 'RenderPipelineProbe baseline'))
    {
        if ($log -notmatch [regex]::Escape($pattern))
        {
            Write-Error "Missing runtime evidence: $pattern"
            exit 1
        }
    }
}

Write-Output 'Render pipeline baseline verified.'
