param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,
    [switch]$TrackedOnly,
    [switch]$RequireProjectLayout
)

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    Write-Error "Repository root is missing: $root"
    exit 1
}

$forbiddenPathPattern = '(^|/)(\.vs|Binaries|DerivedDataCache|Intermediate|Saved)(/|$)|(^|/)Content/Developers(/|$)|(^|/)Build/Windows/FileOpenOrder(/|$)|\.(sln|slnx|pdb|wpix|rdc|ngfx-capture)$'
$secretPattern = '(?i)(SecurityToken\s*=|gh[pousr]_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'

if ($TrackedOnly) {
    $relativeFiles = @(git -C $root ls-files)
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'git ls-files failed.'
        exit 1
    }
}
else {
    $relativeFiles = @(
        Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            ForEach-Object {
                [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/')
            }
    )
}

$failures = [Collections.Generic.List[string]]::new()
$requiredPaths = @(
    'RenderPipelineLab.uproject',
    '.github/workflows/repository-checks.yml',
    'Source/RenderPipelineLab.Target.cs',
    'Source/RenderPipelineLabEditor.Target.cs',
    'Source/RenderPipelineLab/RenderPipelineLab.Build.cs',
    'Source/RenderPipelineLab/Core/RenderPipelinePhaseRegistry.cpp',
    'Source/RenderPipelineLab/Phases/Phase0_StaticBox/Phase0StaticBoxActor.cpp',
    'Source/RenderPipelineLab/Phases/Phase1_DirectLighting/Phase1DirectLightingActor.cpp'
)

if ($RequireProjectLayout) {
    foreach ($required in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $required) -PathType Leaf)) {
            $failures.Add("Missing required path: $required")
        }
    }
}

foreach ($relative in $relativeFiles) {
    if ($relative -match '(^|/)\.git(/|$)') {
        continue
    }
    if ($relative -match $forbiddenPathPattern) {
        $failures.Add("Forbidden path: $relative")
        continue
    }

    $fullPath = Join-Path $root $relative
    $extension = [IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    if ($extension -in @(
        '.cpp', '.h', '.cs', '.ini', '.md', '.ps1', '.yml', '.yaml',
        '.json', '.uproject', '.gitignore', '.gitattributes', '.vsconfig')) {
        $content = Get-Content -Raw -LiteralPath $fullPath -ErrorAction SilentlyContinue
        if ($content -match $secretPattern) {
            $failures.Add("Sensitive content: $relative")
        }

        if ($extension -eq '.uproject') {
            try {
                $project = $content | ConvertFrom-Json -ErrorAction Stop
                $androidFileServer = @($project.Plugins) | Where-Object {
                    $_.Name -eq 'AndroidFileServer'
                } | Select-Object -First 1
                if (-not $androidFileServer -or $androidFileServer.Enabled -ne $false) {
                    $failures.Add(
                        "AndroidFileServer must be explicitly disabled: $relative")
                }
            }
            catch {
                $failures.Add("Invalid uproject JSON: $relative")
            }
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Repository tree validated.'
