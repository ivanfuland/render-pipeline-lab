# RenderPipelineLab Monorepo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Historical path note:** This plan records the repository layout used during the original implementation. The current layout stores BAT entry points in `Tools/` and PowerShell implementations/tests in `Tools/Scripts/`; commands below that reference `Tools/*.ps1` are historical, not current operational instructions. Use the root `README.md` for current commands.

**Goal:** Rename the existing UE 5.8.1 `test` project to `RenderPipelineLab`, add a single-project Phase Registry, preserve the white Box experiment as Phase0, implement the `060` Direct Lighting experiment as Phase1, and publish the verified source to `ivanfuland/render-pipeline-lab`.

**Architecture:** One `.uproject` and one Runtime Module host multiple C++-created experiment Actors selected by `-RenderPipelinePhase=Phase0|Phase1`. Phase0 preserves the existing component lifecycle probe; Phase1 creates the fixed Box/Plane/Movable Spot Light/Camera scene and uses separate Shadow On/Off processes. Git tracks reproducible inputs only; local UE builds and GPU captures are verification gates and never enter Git.

**Tech Stack:** Unreal Engine 5.8.1 C++, UnrealBuildTool, UE Automation Tests, PowerShell 7, Git/Git LFS, GitHub Actions, PIX 2603.25, D3D12/SM6.

**Spec:** `docs/superpowers/specs/2026-09-02-render-pipeline-lab-monorepo-design.md`

## Global Constraints

- Engine source: `H:\Unreal\UnrealEngine`, branch `study-ue-5.8.1`, commit `71fe36aac5a8df5ccd66c763ffc902b29b6a9c43`.
- Current project root: `H:\Unreal\Workspace\test`; target root: `H:\Unreal\Workspace\RenderPipelineLab`.
- Resolve and verify both absolute paths before the directory move; the destination must not exist.
- Do not kill Unreal Editor, Visual Studio, UBT, UAT, Cook, or capture processes automatically. Stop and report their PIDs if they reference this project.
- One `.uproject`, one Runtime Module, Phase0 default, Phase1 explicit.
- Phase1 fact source: `D:\IvanOneDriveCloud\ivan-ai-driven\862-UE 相关\50-直接光求解\060-Standard Deferred Box 与 Plane：从 GBuffer 与 Shadow Mask 到 Scene Color.md`.
- Phase1 runtime: Windows 11, D3D12, SM6, Standard Deferred, Epic, 1280×1080 Windowed, Dynamic Resolution Off, Traditional Shadow Map + PCF.
- Phase1 disables Clustered Deferred, VSM, Whole-Scene Shadow Cache, Nanite, Substrate, MegaLights, Ray Tracing, Lumen GI/Reflections, Distance Field, and Static Lighting.
- Shadow On and Shadow Off run in separate processes and differ only in Spot Light `CastShadows`.
- NullRHI tests verify CPU contracts only; D3D12 runtime verifies viewport projection; PIX verifies Pass, Shader, and resources.
- Public repository: never stage the current Android File Server `SecurityToken`, credentials, captures, binaries, PDBs, logs, or generated directories.
- Use `apply_patch` for text-file edits. Use explicit `Move-Item -LiteralPath` only for validated project/file renames.
- Preserve unrelated local files and generated outputs; do not use `git reset --hard`, wildcard recursive deletion, or broad cleanup commands.

---

## File Structure

**Project metadata and repository controls**

- Create: `.gitignore` — UE generated-output, capture, developer-content, and secret-safe exclusions.
- Create: `.gitattributes` — text normalization plus Git LFS routing for `.uasset` / `.umap`.
- Track: `.vsconfig` — Visual Studio workload description.
- Create: `.github/workflows/repository-checks.yml` — public repository static checks.
- Create: `Tools/ValidateRepository.ps1` — tracked-tree security and layout validator.
- Create: `Tools/TestValidateRepository.ps1` — dependency-free validator regression tests.

**Renamed Unreal project**

- Rename: `test.uproject` → `RenderPipelineLab.uproject`.
- Rename: `Source/testEditor.Target.cs` → `Source/RenderPipelineLabEditor.Target.cs`.
- Keep and update: `Source/RenderPipelineLab.Target.cs`.
- Rename: `Source/test/` → `Source/RenderPipelineLab/`.
- Rename: `test.Build.cs`, `test.h`, `test.cpp` → `RenderPipelineLab.Build.cs`, `RenderPipelineLab.h`, `RenderPipelineLab.cpp`.
- Modify: `Config/DefaultEngine.ini`, `Config/DefaultGameUserSettings.ini`, `Config/DefaultGame.ini`.

**Core Phase system**

- Create: `Source/RenderPipelineLab/Core/RenderPipelineLabGameMode.h/.cpp`.
- Create: `Source/RenderPipelineLab/Core/RenderPipelinePhaseActor.h/.cpp`.
- Create: `Source/RenderPipelineLab/Core/RenderPipelinePhaseRegistry.h/.cpp`.

**Phase0**

- Create from existing probe: `Source/RenderPipelineLab/Phases/Phase0_StaticBox/Phase0StaticBoxActor.h/.cpp`.
- Update tests: `Source/RenderPipelineLab/Tests/Phase0StaticBoxActorTests.cpp`.

**Phase1**

- Create: `Source/RenderPipelineLab/Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h/.cpp`.
- Create: `Source/RenderPipelineLab/Tests/RenderPipelinePhaseRegistryTests.cpp`.
- Create: `Source/RenderPipelineLab/Tests/Phase1DirectLightingActorTests.cpp`.
- Create: `Tools/RunRenderPipelinePhase.ps1`.
- Create: `Tools/VerifyPhase1Runtime.ps1`.
- Create: `Tools/CapturePhase1Pix.ps1`.
- Create: `docs/phase0-static-box.md`, `docs/phase1-direct-lighting.md`.
- Replace root experiment note with: `README.md`.

---

### Task 1: Create the sanitized public-repository baseline

**Files:**

- Create: `.gitignore`
- Create: `.gitattributes`
- Create: `Tools/ValidateRepository.ps1`
- Create: `Tools/TestValidateRepository.ps1`
- Modify: `Config/DefaultEngine.ini`
- Commit existing: `.vsconfig`, `Config/`, `Source/`, `Tools/`, `test.uproject`, `RENDER_PIPELINE_LAB.md`

**Interfaces:**

- Consumes: existing untracked UE project files and local Git repository containing design commit `95fbee4`.
- Produces: sanitized baseline commit; `ValidateRepository.ps1 -RepositoryRoot <path> [-TrackedOnly]` returning exit `0` only for a safe repository tree.

- [ ] **Step 1: Verify the design commit and repository state**

Run:

```powershell
git -C 'H:\Unreal\Workspace\test' log -1 --oneline
git -C 'H:\Unreal\Workspace\test' status --short
```

Expected: HEAD is the approved design commit; project inputs are untracked; no project implementation changes are staged.

- [ ] **Step 2: Write the validator regression test first**

Create `Tools/TestValidateRepository.ps1` with explicit safe and unsafe fixtures:

```powershell
param([Parameter(Mandatory = $true)][string]$ValidatorPath)

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "RenderPipelineLab-Validator-$PID"
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe test root: $resolvedTemp"
}

function Invoke-ValidatorProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$RequireProjectLayout
    )
    $arguments = @('-NoProfile', '-File', $ValidatorPath, '-RepositoryRoot', $Root)
    if ($RequireProjectLayout) { $arguments += '-RequireProjectLayout' }
    $process = Start-Process -FilePath 'pwsh' -ArgumentList $arguments `
        -WindowStyle Hidden -Wait -PassThru
    return $process.ExitCode
}

try {
    New-Item -ItemType Directory -Path $resolvedTemp | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $resolvedTemp 'Source') | Out-Null
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'Source\Safe.cpp') -Value 'int Safe = 1;'

    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -ne 0) {
        throw 'Safe fixture failed validation.'
    }

    New-Item -ItemType Directory -Path (Join-Path $resolvedTemp 'Saved\Captures') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'Saved\Captures\bad.wpix') -Value 'capture'
    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -eq 0) {
        throw 'Capture fixture unexpectedly passed.'
    }

    Remove-Item -LiteralPath (Join-Path $resolvedTemp 'Saved') -Recurse -Force
    $unsafeAssignment = ('Security' + 'Token=DO_NOT_COMMIT')
    Set-Content -LiteralPath (Join-Path $resolvedTemp 'DefaultEngine.ini') -Value $unsafeAssignment
    if ((Invoke-ValidatorProcess -Root $resolvedTemp) -eq 0) {
        throw 'Credential fixture unexpectedly passed.'
    }
}
finally {
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'Repository validator tests passed.'
```

- [ ] **Step 3: Run the test to verify it fails because the validator is absent**

Run:

```powershell
pwsh -NoProfile -File 'H:\Unreal\Workspace\test\Tools\TestValidateRepository.ps1' `
  -ValidatorPath 'H:\Unreal\Workspace\test\Tools\ValidateRepository.ps1'
```

Expected: FAIL because `ValidateRepository.ps1` does not exist.

- [ ] **Step 4: Implement the repository validator**

Create `Tools/ValidateRepository.ps1`:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [switch]$TrackedOnly
)

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$forbiddenPathPattern = '(^|/)(\.vs|Binaries|DerivedDataCache|Intermediate|Saved)(/|$)|(^|/)Content/Developers(/|$)|(^|/)Build/Windows/FileOpenOrder(/|$)|\.(sln|slnx|pdb|wpix|rdc|ngfx-capture)$'
$secretPattern = '(?i)(SecurityToken\s*=|gh[pousr]_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'

if ($TrackedOnly) {
    $relativeFiles = @(git -C $root ls-files)
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }
}
else {
    $relativeFiles = @(
        Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/') }
    )
}

$failures = [Collections.Generic.List[string]]::new()
foreach ($relative in $relativeFiles) {
    if ($relative -match '(^|/)\.git(/|$)') { continue }
    if ($relative -match $forbiddenPathPattern) {
        $failures.Add("Forbidden path: $relative")
        continue
    }
    $fullPath = Join-Path $root $relative
    $extension = [IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    if ($extension -in @('.cpp','.h','.cs','.ini','.md','.ps1','.yml','.yaml','.json','.uproject','.gitignore','.gitattributes','.vsconfig')) {
        $content = Get-Content -Raw -LiteralPath $fullPath -ErrorAction SilentlyContinue
        if ($content -match $secretPattern) { $failures.Add("Sensitive content: $relative") }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Repository tree validated.'
```

- [ ] **Step 5: Run the validator regression test**

Run the Step 3 command again.

Expected: PASS with `Repository validator tests passed.`

- [ ] **Step 6: Add the UE `.gitignore` and Git LFS rules**

Create `.gitignore`:

```gitignore
.vs/
Binaries/
DerivedDataCache/
Intermediate/
Saved/
*.sln
*.slnx
*.pdb
*.wpix
*.rdc
*.ngfx-capture
Build/Windows/FileOpenOrder/
Content/Developers/
```

Create `.gitattributes`:

```gitattributes
* text=auto
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf
*.uasset filter=lfs diff=lfs merge=lfs -text
*.umap filter=lfs diff=lfs merge=lfs -text
```

Run:

```powershell
git lfs version
git lfs install --local
```

Expected: Git LFS 3.7.1 or newer is available; local hooks install successfully.

- [ ] **Step 7: Remove the generated Android File Server token before staging**

Use `apply_patch` to remove the entire section beginning with:

```ini
[/Script/AndroidFileServerEditor.AndroidFileServerRuntimeSettings]
```

through its `ManualIPAddress=` line from `Config/DefaultEngine.ini`. Do not copy the existing token into a backup inside the repository.

Also add this entry to the `.uproject` Plugins array before launching Editor again:

```json
{ "Name": "AndroidFileServer", "Enabled": false }
```

The plugin is `EnabledByDefault=true`; its Editor settings object writes a generated token back to `DefaultEngine.ini` during startup unless the plugin is explicitly disabled.

Run:

```powershell
rg -n -i 'SecurityToken|gh[pousr]_|PRIVATE KEY' `
  'H:\Unreal\Workspace\test\Config' `
  'H:\Unreal\Workspace\test\Source' `
  'H:\Unreal\Workspace\test\Tools' `
  --glob '!ValidateRepository.ps1'
```

Expected: no matches.

- [ ] **Step 8: Stage only reproducible baseline inputs**

Run:

```powershell
git add -- `
  '.gitignore' '.gitattributes' '.vsconfig' `
  'Config' 'Source' 'Tools' 'test.uproject' 'RENDER_PIPELINE_LAB.md'

pwsh -NoProfile -File '.\Tools\ValidateRepository.ps1' -RepositoryRoot . -TrackedOnly
git diff --cached --check
git diff --cached --name-only
```

Expected: validator and diff checks pass; no generated directory, capture, binary, PDB, solution, developer content, or token is staged.

- [ ] **Step 9: Commit the sanitized Phase0 baseline**

```powershell
git commit -m 'chore: archive original render pipeline probe'
```

Expected: design commit plus sanitized baseline commit; working tree contains ignored generated outputs only.

---

### Task 2: Rename the project and add the Phase Registry with Phase0 compatibility

**Files:**

- Rename and modify project/module/Target files listed in File Structure.
- Create: `Source/RenderPipelineLab/Core/*`
- Create: `Source/RenderPipelineLab/Phases/Phase0_StaticBox/*`
- Create: `Source/RenderPipelineLab/Tests/RenderPipelinePhaseRegistryTests.cpp`
- Create: `Source/RenderPipelineLab/Tests/Phase0StaticBoxActorTests.cpp`
- Modify: `Config/DefaultEngine.ini`, `Tools/VerifyRenderPipelineBaseline.ps1`, root documentation.

**Interfaces:**

- Consumes: sanitized baseline commit; Phase IDs `Phase0`, `Phase1`.
- Produces:
  - `TSubclassOf<ARenderPipelinePhaseActor> FRenderPipelinePhaseRegistry::Resolve(FName PhaseId)`;
  - `FName FRenderPipelinePhaseRegistry::GetDefaultPhaseId()` returning `Phase0`;
  - `ARenderPipelineLabGameMode` command-line selection;
  - Phase0 behavior compatible with the previous probe.

- [ ] **Step 1: Verify directory-move preconditions**

Run:

```powershell
$source = [IO.Path]::GetFullPath('H:\Unreal\Workspace\test')
$destination = [IO.Path]::GetFullPath('H:\Unreal\Workspace\RenderPipelineLab')
"SOURCE=$source"
"DESTINATION=$destination"
if ($source -ne 'H:\Unreal\Workspace\test') { throw 'Unexpected source path.' }
if ($destination -ne 'H:\Unreal\Workspace\RenderPipelineLab') { throw 'Unexpected destination path.' }
if (-not (Test-Path -LiteralPath $source)) { throw 'Source project is missing.' }
if (Test-Path -LiteralPath $destination) { throw 'Destination already exists.' }

Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*H:\Unreal\Workspace\test*' } |
  Select-Object ProcessId, Name, CommandLine
```

Expected: exact paths are printed, destination is absent, and no matching process is listed. If a process is listed, stop and ask the user to close it.

- [ ] **Step 2: Move the project directory as one validated operation**

Run only after Step 1 passes:

```powershell
Set-Location -LiteralPath 'H:\Unreal\Workspace'
Move-Item -LiteralPath 'H:\Unreal\Workspace\test' `
  -Destination 'H:\Unreal\Workspace\RenderPipelineLab'
```

Expected: `.git` and all project content now resolve under the target path; the old path is absent.

- [ ] **Step 3: Perform the mechanical project and module rename**

Use explicit file moves:

```powershell
$root = 'H:\Unreal\Workspace\RenderPipelineLab'
Move-Item -LiteralPath "$root\test.uproject" -Destination "$root\RenderPipelineLab.uproject"
Move-Item -LiteralPath "$root\Source\testEditor.Target.cs" -Destination "$root\Source\RenderPipelineLabEditor.Target.cs"
Move-Item -LiteralPath "$root\Source\test" -Destination "$root\Source\RenderPipelineLab"
Move-Item -LiteralPath "$root\Source\RenderPipelineLab\test.Build.cs" -Destination "$root\Source\RenderPipelineLab\RenderPipelineLab.Build.cs"
Move-Item -LiteralPath "$root\Source\RenderPipelineLab\test.h" -Destination "$root\Source\RenderPipelineLab\RenderPipelineLab.h"
Move-Item -LiteralPath "$root\Source\RenderPipelineLab\test.cpp" -Destination "$root\Source\RenderPipelineLab\RenderPipelineLab.cpp"
```

Update `RenderPipelineLab.uproject`:

```json
{
  "FileVersion": 3,
  "EngineAssociation": "{FA62D087-46FC-3099-23CA-1085715EFF39}",
  "Category": "",
  "Description": "Reproducible UE renderer experiments organized as phases.",
  "Modules": [
    { "Name": "RenderPipelineLab", "Type": "Runtime", "LoadingPhase": "Default" }
  ],
  "Plugins": [
    {
      "Name": "ModelingToolsEditorMode",
      "Enabled": true,
      "TargetAllowList": ["Editor"]
    }
  ]
}
```

Update both Target files to `ExtraModuleNames.Add("RenderPipelineLab")`. Rename the Editor Target class to `RenderPipelineLabEditorTarget`. Rename the ModuleRules class to `RenderPipelineLab`. Update the primary module:

```cpp
#include "RenderPipelineLab.h"
#include "Modules/ModuleManager.h"

IMPLEMENT_PRIMARY_GAME_MODULE(
    FDefaultGameModuleImpl,
    RenderPipelineLab,
    "RenderPipelineLab");
```

Replace `TEST_API` with `RENDERPIPELINELAB_API`.

Do not implement the Phase Registry or renamed Phase0 class in this step. The renamed metadata provides a buildable target name for the following red test.

- [ ] **Step 4: Write failing Phase Registry tests**

Create `Source/RenderPipelineLab/Tests/RenderPipelinePhaseRegistryTests.cpp`:

```cpp
#if WITH_DEV_AUTOMATION_TESTS
#include "Misc/AutomationTest.h"
#include "Core/RenderPipelinePhaseRegistry.h"
#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FRenderPipelinePhaseRegistryTest,
    "Project.RenderPipelineLab.Registry.ResolvesKnownPhases",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FRenderPipelinePhaseRegistryTest::RunTest(const FString& Parameters)
{
    TestEqual(TEXT("Default Phase"),
        FRenderPipelinePhaseRegistry::GetDefaultPhaseId(), FName(TEXT("Phase0")));
    TestEqual(TEXT("Phase0 Class"),
        FRenderPipelinePhaseRegistry::Resolve(FName(TEXT("Phase0"))).Get(),
        APhase0StaticBoxActor::StaticClass());
    TestNull(TEXT("Unknown Phase"),
        FRenderPipelinePhaseRegistry::Resolve(FName(TEXT("Unknown"))).Get());
    return true;
}
#endif
```

- [ ] **Step 5: Run the Editor build to verify the test fails**

Run:

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  RenderPipelineLabEditor Win64 Development `
  'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -WaitMutex -NoHotReloadFromIDE
```

Expected: FAIL because `RenderPipelinePhaseRegistry.h` and Phase0 renamed classes are not implemented.

- [ ] **Step 6: Implement the Phase base and Registry**

Create `Core/RenderPipelinePhaseActor.h`:

```cpp
#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RenderPipelinePhaseActor.generated.h"

UCLASS(Abstract)
class RENDERPIPELINELAB_API ARenderPipelinePhaseActor : public AActor
{
    GENERATED_BODY()
public:
    virtual FName GetPhaseId() const PURE_VIRTUAL(ARenderPipelinePhaseActor::GetPhaseId, return NAME_None;);
protected:
    void LogPhaseReady() const;
    void SchedulePixCaptureIfRequested();
private:
    void TriggerPixCapture();
    FTimerHandle PixCaptureTimer;
};
```

Declare the shared log category in `RenderPipelineLab.h` and define it in `RenderPipelineLab.cpp`:

```cpp
DECLARE_LOG_CATEGORY_EXTERN(LogRenderPipelineLab, Log, All);
```

```cpp
DEFINE_LOG_CATEGORY(LogRenderPipelineLab);
```

Implement common capture scheduling in `RenderPipelinePhaseActor.cpp`:

```cpp
void ARenderPipelinePhaseActor::SchedulePixCaptureIfRequested()
{
    if (!FParse::Param(FCommandLine::Get(), TEXT("pixautocapture"))) return;
    GetWorldTimerManager().SetTimer(
        PixCaptureTimer, this,
        &ARenderPipelinePhaseActor::TriggerPixCapture, 5.0f, false);
}

void ARenderPipelinePhaseActor::TriggerPixCapture()
{
    UE_LOG(LogRenderPipelineLab, Display,
        TEXT("Phase=%s Stage=PixCaptureRequested Command=pix.GpuCaptureFrame"),
        *GetPhaseId().ToString());
    if (!GEngine->Exec(GetWorld(), TEXT("pix.GpuCaptureFrame")))
    {
        UE_LOG(LogRenderPipelineLab, Error,
            TEXT("Phase=%s Stage=PixCaptureFailed Reason=CommandUnavailable"),
            *GetPhaseId().ToString());
    }
}
```

Phase0 and Phase1 call `SchedulePixCaptureIfRequested()` only after their own `Stage=Ready` conditions pass.

Create `Core/RenderPipelinePhaseRegistry.h`:

```cpp
#pragma once
#include "CoreMinimal.h"

class ARenderPipelinePhaseActor;

class RENDERPIPELINELAB_API FRenderPipelinePhaseRegistry
{
public:
    static FName GetDefaultPhaseId();
    static TSubclassOf<ARenderPipelinePhaseActor> Resolve(FName PhaseId);
};
```

Implement `Resolve` as explicit runtime switches calling `StaticClass()`; do not store `UClass*` in global static initialization:

```cpp
#include "Phases/Phase0_StaticBox/Phase0StaticBoxActor.h"
#include "Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h"

FName FRenderPipelinePhaseRegistry::GetDefaultPhaseId()
{
    return FName(TEXT("Phase0"));
}

TSubclassOf<ARenderPipelinePhaseActor> FRenderPipelinePhaseRegistry::Resolve(FName PhaseId)
{
    if (PhaseId == FName(TEXT("Phase0"))) return APhase0StaticBoxActor::StaticClass();
    if (PhaseId == FName(TEXT("Phase1"))) return APhase1DirectLightingActor::StaticClass();
    return nullptr;
}
```

Task 2 resolves Phase1 to a minimal class declaration so the registry compiles; Task 3 replaces the stub with the tested scene contract.

Create the Task 2 Phase1 stub at `Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h`:

```cpp
#pragma once
#include "Core/RenderPipelinePhaseActor.h"
#include "Phase1DirectLightingActor.generated.h"

UCLASS()
class RENDERPIPELINELAB_API APhase1DirectLightingActor final
    : public ARenderPipelinePhaseActor
{
    GENERATED_BODY()
public:
    virtual FName GetPhaseId() const override { return FName(TEXT("Phase1")); }
};
```

Create a `.cpp` containing only the matching include. Task 3 replaces this stub with the tested scene contract.

- [ ] **Step 7: Implement the Game Mode selection and explicit failure**

Create `Core/RenderPipelineLabGameMode.cpp` with this selection contract:

```cpp
void ARenderPipelineLabGameMode::BeginPlay()
{
    Super::BeginPlay();
    FString PhaseValue;
    const bool bHasPhase = FParse::Value(
        FCommandLine::Get(), TEXT("RenderPipelinePhase="), PhaseValue);
    const FName PhaseId = bHasPhase
        ? FName(*PhaseValue)
        : FRenderPipelinePhaseRegistry::GetDefaultPhaseId();

    const TSubclassOf<ARenderPipelinePhaseActor> PhaseClass =
        FRenderPipelinePhaseRegistry::Resolve(PhaseId);
    if (!PhaseClass)
    {
        UE_LOG(LogRenderPipelineLab, Error,
            TEXT("Stage=StartupFailed Reason=UnknownPhase Phase=%s"), *PhaseId.ToString());
        FPlatformMisc::RequestExitWithStatus(true, 2);
        return;
    }

    UWorld* World = GetWorld();
    if (!World)
    {
        UE_LOG(LogRenderPipelineLab, Error,
            TEXT("Stage=StartupFailed Reason=NoWorld Phase=%s"), *PhaseId.ToString());
        FPlatformMisc::RequestExitWithStatus(true, 4);
        return;
    }
    ARenderPipelinePhaseActor* PhaseActor = World->SpawnActor<ARenderPipelinePhaseActor>(
        PhaseClass, FVector::ZeroVector, FRotator::ZeroRotator);
    if (!PhaseActor)
    {
        UE_LOG(LogRenderPipelineLab, Error,
            TEXT("Stage=StartupFailed Reason=SpawnFailed Phase=%s"), *PhaseId.ToString());
        FPlatformMisc::RequestExitWithStatus(true, 5);
    }
}
```

Include `Core/RenderPipelinePhaseActor.h`, `Core/RenderPipelinePhaseRegistry.h`, `Engine/World.h`, `HAL/PlatformMisc.h`, and `Misc/CommandLine.h` explicitly.

- [ ] **Step 8: Migrate the existing Actor to Phase0 and preserve behavior**

Move the old `RenderPipelineProbeActor` implementation into `Phase0StaticBoxActor`. Preserve component tag `RenderPipelineProbe.Box`, keys `1`–`4`, `-pixautocapture`, unique component generation, Basic Shape Material, and existing log stages. Add `Phase=Phase0` to each log line.

Use explicit source moves before class renaming:

```powershell
$module = 'H:\Unreal\Workspace\RenderPipelineLab\Source\RenderPipelineLab'
New-Item -ItemType Directory -Path "$module\Phases\Phase0_StaticBox" -Force | Out-Null
Move-Item -LiteralPath "$module\RenderPipelineProbeActor.h" `
  -Destination "$module\Phases\Phase0_StaticBox\Phase0StaticBoxActor.h"
Move-Item -LiteralPath "$module\RenderPipelineProbeActor.cpp" `
  -Destination "$module\Phases\Phase0_StaticBox\Phase0StaticBoxActor.cpp"
Move-Item -LiteralPath "$module\Tests\RenderPipelineProbeActorTests.cpp" `
  -Destination "$module\Tests\Phase0StaticBoxActorTests.cpp"
```

Rename `ARenderPipelineProbeActor` to `APhase0StaticBoxActor`, retain the existing public action methods, and implement:

```cpp
virtual FName GetPhaseId() const override { return FName(TEXT("Phase0")); }
```

After `ARenderPipelineLabGameMode` is implemented, remove the superseded project-owned files with `apply_patch` delete operations:

```text
Source/RenderPipelineLab/RenderPipelineProbeGameMode.h
Source/RenderPipelineLab/RenderPipelineProbeGameMode.cpp
```

No behavior remains in those files: Phase selection belongs to `ARenderPipelineLabGameMode`, and Phase0 behavior belongs to `APhase0StaticBoxActor`.

Update the existing lifecycle test to instantiate `APhase0StaticBoxActor` and keep all prior assertions. Add:

```cpp
TestEqual(TEXT("Phase ID"), Probe->GetPhaseId(), FName(TEXT("Phase0")));
```

- [ ] **Step 9: Update Unreal configuration and redirects**

Update `Config/DefaultEngine.ini`:

```ini
[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Engine/Maps/Entry
EditorStartupMap=/Engine/Maps/Entry
GlobalDefaultGameMode=/Script/RenderPipelineLab.RenderPipelineLabGameMode

[/Script/Engine.Engine]
+ActiveGameNameRedirects=(OldGameName="test",NewGameName="/Script/RenderPipelineLab")
+ActiveGameNameRedirects=(OldGameName="/Script/test",NewGameName="/Script/RenderPipelineLab")
```

Update `VerifyRenderPipelineBaseline.ps1` to require the new `.uproject`, Module, Target, and Game Mode names and to reject `/Script/test` outside redirect lines.

- [ ] **Step 10: Generate project files and build the renamed Editor Target**

Run:

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\GenerateProjectFiles.bat' `
  -project='H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -game -engine

& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  RenderPipelineLabEditor Win64 Development `
  'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -WaitMutex -NoHotReloadFromIDE
```

Expected: both commands exit `0`.

- [ ] **Step 11: Run Registry and Phase0 Automation Tests**

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor-Cmd.exe' `
  'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -Unattended -NoSplash -NullRHI `
  '-ExecCmds=Automation RunTests Project.RenderPipelineLab;Quit' `
  '-TestExit=Automation Test Queue Empty' `
  '-Log=RenderPipelineLabTests.log'

rg -n 'Test Completed\. Result=\{Success\}' `
  'H:\Unreal\Workspace\RenderPipelineLab\Saved\Logs\RenderPipelineLabTests.log'
```

Expected: registry and Phase0 tests report Success; no failure or error summary.

- [ ] **Step 12: Run Phase0 smoke verification**

Launch with `-RenderPipelinePhase=Phase0`, wait for `Phase=Phase0 Stage=Ready`, and manually exercise keys `1`–`4`. Confirm transform, dirty, destroy, and recreate logs still occur.

- [ ] **Step 13: Verify unknown Phase failure behavior**

```powershell
$process = Start-Process `
  -FilePath 'H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor.exe' `
  -ArgumentList @(
    'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject',
    '-game', '-Unattended', '-RenderPipelinePhase=Unknown',
    '-log', '-Log=UnknownPhase.log'
  ) `
  -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 2) { throw "Expected exit 2, got $($process.ExitCode)." }
$log = Get-Content -Raw -LiteralPath `
  'H:\Unreal\Workspace\RenderPipelineLab\Saved\Logs\UnknownPhase.log'
if ($log -notmatch 'Reason=UnknownPhase') { throw 'UnknownPhase error missing.' }
if ($log -match 'Stage=Ready') { throw 'Unknown Phase reached Ready.' }
```

- [ ] **Step 14: Commit the rename, Registry, and Phase0 migration**

```powershell
git add --all
pwsh -NoProfile -File '.\Tools\ValidateRepository.ps1' -RepositoryRoot . -TrackedOnly
git diff --cached --check
git commit -m 'refactor: rename project and add phase registry'
```

Expected: commit contains no generated solutions or build outputs; Phase0 and registry validation already passed.

---

### Task 3: Implement and verify Phase1 Direct Lighting

**Files:**

- Create/modify Phase1, tests, config, tools, README, and Phase docs listed in File Structure.

**Interfaces:**

- Consumes: Registry `Phase1` mapping; fixed runtime boundary from `060`.
- Produces:
  - `APhase1DirectLightingActor` component getters for tests;
  - `enum class EPhase1ShadowMode : uint8 { On, Off }`;
  - `static TOptional<EPhase1ShadowMode> ParseShadowMode(const TCHAR* CommandLine)`;
  - deterministic `TargetWorldPosition` and logged `FIntPoint TargetScreenPosition`;
  - `VerifyPhase1Runtime.ps1` comparing Shadow On/Off logs;
  - local PIX evidence and committed evidence metadata.

- [ ] **Step 1: Write failing Phase1 contract tests**

Create `Tests/Phase1DirectLightingActorTests.cpp` with tests for component existence and settings:

```cpp
#if WITH_DEV_AUTOMATION_TESTS
#include "Misc/AutomationTest.h"
#include "Phases/Phase1_DirectLighting/Phase1DirectLightingActor.h"
#include "Components/SpotLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FPhase1DirectLightingContractTest,
    "Project.RenderPipelineLab.Phase1.ComponentContract",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FPhase1DirectLightingContractTest::RunTest(const FString& Parameters)
{
    UWorld* World = UWorld::CreateWorld(
        EWorldType::Game, false, FName(TEXT("Phase1ContractTestWorld")));
    TestNotNull(TEXT("World"), World);
    if (!World) return false;
    World->AddToRoot();
    APhase1DirectLightingActor* Actor = World->SpawnActor<APhase1DirectLightingActor>();
    TestNotNull(TEXT("Actor"), Actor);
    if (!Actor) {
        World->RemoveFromRoot();
        World->DestroyWorld(false);
        return false;
    }
    TestNotNull(TEXT("Box"), Actor->GetBoxCaster());
    TestNotNull(TEXT("Plane"), Actor->GetPlaneReceiver());
    TestNotNull(TEXT("Spot"), Actor->GetSpotLight());
    TestNotNull(TEXT("Camera"), Actor->GetCamera());
    TestTrue(TEXT("Box casts"), Actor->GetBoxCaster()->CastShadow);
    TestFalse(TEXT("Plane does not cast"), Actor->GetPlaneReceiver()->CastShadow);
    TestEqual(TEXT("Box mobility"), Actor->GetBoxCaster()->GetMobility(), EComponentMobility::Static);
    TestEqual(TEXT("Plane mobility"), Actor->GetPlaneReceiver()->GetMobility(), EComponentMobility::Static);
    TestEqual(TEXT("Spot mobility"), Actor->GetSpotLight()->GetMobility(), EComponentMobility::Movable);
    TestEqual(TEXT("Spot source radius"), Actor->GetSpotLight()->SourceRadius, 0.0f);
    TestEqual(TEXT("Spot source length"), Actor->GetSpotLight()->SourceLength, 0.0f);
    TestEqual(TEXT("Spot contact shadow"), Actor->GetSpotLight()->ContactShadowLength, 0.0f);
    TestNull(TEXT("Spot IES"), Actor->GetSpotLight()->IESTexture.Get());
    TestNull(TEXT("Spot light function"), Actor->GetSpotLight()->LightFunctionMaterial.Get());
    TestFalse(TEXT("Spot disallows MegaLights"), Actor->GetSpotLight()->bAllowMegaLights);
    TestTrue(TEXT("Default lighting channel"), Actor->GetSpotLight()->LightingChannels.bChannel0);
    TestFalse(TEXT("Lighting channel 1 disabled"), Actor->GetSpotLight()->LightingChannels.bChannel1);
    TestFalse(TEXT("Lighting channel 2 disabled"), Actor->GetSpotLight()->LightingChannels.bChannel2);
    TestEqual(TEXT("Phase ID"), Actor->GetPhaseId(), FName(TEXT("Phase1")));
    World->RemoveFromRoot();
    World->DestroyWorld(false);
    return true;
}
#endif
```

Add a second test:

```cpp
IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FPhase1ShadowModeParseTest,
    "Project.RenderPipelineLab.Phase1.ShadowModeParsing",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FPhase1ShadowModeParseTest::RunTest(const FString& Parameters)
{
    const auto On = APhase1DirectLightingActor::ParseShadowMode(
        TEXT("-Phase1Shadow=On"));
    const auto Off = APhase1DirectLightingActor::ParseShadowMode(
        TEXT("-Phase1Shadow=Off"));
    const auto Invalid = APhase1DirectLightingActor::ParseShadowMode(
        TEXT("-Phase1Shadow=Invalid"));
    TestTrue(TEXT("On parsed"), On.IsSet() && On.GetValue() == EPhase1ShadowMode::On);
    TestTrue(TEXT("Off parsed"), Off.IsSet() && Off.GetValue() == EPhase1ShadowMode::Off);
    TestFalse(TEXT("Invalid rejected"), Invalid.IsSet());
    return true;
}
```

- [ ] **Step 2: Build to verify Phase1 tests fail**

Run the Editor build command from Task 2.

Expected: FAIL because Phase1 interfaces and components are not implemented.

- [ ] **Step 3: Define the Phase1 Actor interface and stable constants**

Create `Phase1DirectLightingActor.h`:

```cpp
#pragma once
#include "CoreMinimal.h"
#include "Core/RenderPipelinePhaseActor.h"
#include "Phase1DirectLightingActor.generated.h"

class UCameraComponent;
class USceneComponent;
class USpotLightComponent;
class UStaticMeshComponent;

UENUM()
enum class EPhase1ShadowMode : uint8 { On, Off };

UCLASS()
class RENDERPIPELINELAB_API APhase1DirectLightingActor final
    : public ARenderPipelinePhaseActor
{
    GENERATED_BODY()
public:
    APhase1DirectLightingActor();
    virtual void BeginPlay() override;
    virtual FName GetPhaseId() const override { return FName(TEXT("Phase1")); }
    static TOptional<EPhase1ShadowMode> ParseShadowMode(const TCHAR* CommandLine);
    UStaticMeshComponent* GetBoxCaster() const { return BoxCaster; }
    UStaticMeshComponent* GetPlaneReceiver() const { return PlaneReceiver; }
    USpotLightComponent* GetSpotLight() const { return SpotLight; }
    UCameraComponent* GetCamera() const { return Camera; }
    static FVector GetReceiverTargetWorldPosition();
private:
    void ValidateAndLogReady();
    UPROPERTY()
    TObjectPtr<USceneComponent> SceneRoot;
    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> BoxCaster;
    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> PlaneReceiver;
    UPROPERTY()
    TObjectPtr<USpotLightComponent> SpotLight;
    UPROPERTY()
    TObjectPtr<UCameraComponent> Camera;
    EPhase1ShadowMode ShadowMode = EPhase1ShadowMode::On;
    FTimerHandle ReadyTimer;
};
```

Use named constants in the `.cpp`:

```cpp
namespace Phase1DirectLighting
{
    const FVector PlaneLocation(0.0, 0.0, 0.0);
    const FVector PlaneScale(10.0, 10.0, 1.0);
    const FVector BoxLocation(0.0, 0.0, 50.0);
    const FVector BoxScale(1.0, 1.0, 1.0);
    const FVector SpotLocation(-300.0, -200.0, 400.0);
    const FVector ReceiverTarget(100.0, 60.0, 1.0);
    const FVector CameraLocation(0.0, -900.0, 500.0);
    const FVector CameraTarget(60.0, 0.0, 30.0);
    constexpr float CameraFov = 60.0f;
    constexpr float SpotIntensity = 300.0f;
    constexpr float SpotRadius = 1500.0f;
    constexpr float SpotInnerCone = 20.0f;
    constexpr float SpotOuterCone = 35.0f;
}
```

These are the accepted post-smoke constants. They keep the Box readable, separate it from the Plane shadow, and place the receiver target near the projected shadow center. The values are frozen in source and `docs/phase1-direct-lighting.md` before PIX capture.

- [ ] **Step 4: Implement the C++-created Phase1 scene**

In the constructor:

```cpp
static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeFinder(
    TEXT("/Engine/BasicShapes/Cube.Cube"));
static ConstructorHelpers::FObjectFinder<UStaticMesh> PlaneFinder(
    TEXT("/Engine/BasicShapes/Plane.Plane"));
static ConstructorHelpers::FObjectFinder<UMaterialInterface> MaterialFinder(
    TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
check(CubeFinder.Succeeded() && PlaneFinder.Succeeded() && MaterialFinder.Succeeded());
UStaticMesh* CubeAsset = CubeFinder.Object;
UStaticMesh* PlaneAsset = PlaneFinder.Object;
UMaterialInterface* BasicMaterial = MaterialFinder.Object;

SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
SetRootComponent(SceneRoot);
BoxCaster = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Phase1_BoxCaster"));
PlaneReceiver = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Phase1_PlaneReceiver"));
SpotLight = CreateDefaultSubobject<USpotLightComponent>(TEXT("Phase1_MovableSpotLight"));
Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Phase1_FixedCamera"));
BoxCaster->SetupAttachment(SceneRoot);
PlaneReceiver->SetupAttachment(SceneRoot);
SpotLight->SetupAttachment(SceneRoot);
Camera->SetupAttachment(SceneRoot);

BoxCaster->SetStaticMesh(CubeAsset);
BoxCaster->SetMaterial(0, BasicMaterial);
BoxCaster->SetMobility(EComponentMobility::Static);
BoxCaster->SetCastShadow(true);
BoxCaster->SetRelativeLocation(Phase1DirectLighting::BoxLocation);
BoxCaster->SetRelativeScale3D(Phase1DirectLighting::BoxScale);

PlaneReceiver->SetStaticMesh(PlaneAsset);
PlaneReceiver->SetMaterial(0, BasicMaterial);
PlaneReceiver->SetMobility(EComponentMobility::Static);
PlaneReceiver->SetCastShadow(false);
PlaneReceiver->SetRelativeLocation(Phase1DirectLighting::PlaneLocation);
PlaneReceiver->SetRelativeScale3D(Phase1DirectLighting::PlaneScale);

SpotLight->SetMobility(EComponentMobility::Movable);
SpotLight->SetIntensityUnits(ELightUnits::Lumens);
SpotLight->SetIntensity(Phase1DirectLighting::SpotIntensity);
SpotLight->SetAttenuationRadius(Phase1DirectLighting::SpotRadius);
SpotLight->SetInnerConeAngle(Phase1DirectLighting::SpotInnerCone);
SpotLight->SetOuterConeAngle(Phase1DirectLighting::SpotOuterCone);
SpotLight->SetSourceRadius(0.0f);
SpotLight->SetSoftSourceRadius(0.0f);
SpotLight->SetSourceLength(0.0f);
SpotLight->ContactShadowLength = 0.0f;
SpotLight->ContactShadowLengthInWS = 0;
SpotLight->SetLightingChannels(true, false, false);
SpotLight->SetIESTexture(nullptr);
SpotLight->SetLightFunctionMaterial(nullptr);
SpotLight->bAllowMegaLights = false;
SpotLight->SetRelativeLocation(Phase1DirectLighting::SpotLocation);
SpotLight->SetRelativeRotation(UKismetMathLibrary::FindLookAtRotation(
    Phase1DirectLighting::SpotLocation,
    Phase1DirectLighting::ReceiverTarget));

Camera->SetRelativeLocation(Phase1DirectLighting::CameraLocation);
Camera->SetRelativeRotation(UKismetMathLibrary::FindLookAtRotation(
    Phase1DirectLighting::CameraLocation,
    Phase1DirectLighting::CameraTarget));
Camera->FieldOfView = Phase1DirectLighting::CameraFov;
```

Include `Camera/CameraComponent.h`, `Components/SceneComponent.h`, `Components/SpotLightComponent.h`, `Components/StaticMeshComponent.h`, `Kismet/KismetMathLibrary.h`, `Materials/MaterialInterface.h`, and `UObject/ConstructorHelpers.h` explicitly.

- [ ] **Step 5: Implement strict Shadow mode parsing**

```cpp
TOptional<EPhase1ShadowMode> APhase1DirectLightingActor::ParseShadowMode(
    const TCHAR* CommandLine)
{
    FString Value;
    if (!FParse::Value(CommandLine, TEXT("Phase1Shadow="), Value))
        return EPhase1ShadowMode::On;
    if (Value.Equals(TEXT("On"), ESearchCase::IgnoreCase))
        return EPhase1ShadowMode::On;
    if (Value.Equals(TEXT("Off"), ESearchCase::IgnoreCase))
        return EPhase1ShadowMode::Off;
    return {};
}
```

`BeginPlay` rejects invalid values with `Stage=StartupFailed Reason=InvalidShadowMode`, requests exit status `3`, and does not emit `Stage=Ready`. Valid modes call `SpotLight->SetCastShadows(ShadowMode == On)` before readiness validation.

- [ ] **Step 6: Configure and validate the exact Phase1 runtime boundary**

Add to `Config/DefaultEngine.ini` `[ConsoleVariables]`:

```ini
r.UseClusteredDeferredShading_ToBeRemoved=0
r.Shadow.FilterMethod=0
r.Shadow.CacheWholeSceneShadows=0
r.MegaLights.Allowed=0
```

Add to `Config/DefaultGameUserSettings.ini`:

```ini
[ScalabilityGroups]
sg.ResolutionQuality=100
sg.ViewDistanceQuality=3
sg.AntiAliasingQuality=3
sg.ShadowQuality=3
sg.GlobalIlluminationQuality=3
sg.ReflectionQuality=3
sg.PostProcessQuality=3
sg.TextureQuality=3
sg.EffectsQuality=3
sg.FoliageQuality=3
sg.ShadingQuality=3
sg.LandscapeQuality=3
```

Implement a fixed array of required CVars and expected values. Log every value. `sg.ResolutionQuality` is record-only and must match between evidence runs; UE5.8.1 uses `0` to select the project's default Screen Percentage. `r.ClusteredDeferredShading.EnableForProject` is also record-only: Clustered Deferred is disabled by `r.UseClusteredDeferredShading_ToBeRemoved=0`, while the project-support CVar may remain `1`. If any other required CVar is missing or mismatched, log `Stage=ReadyFailed Reason=BaselineMismatch` and withhold readiness. Do not mutate read-only project CVars at runtime.

- [ ] **Step 7: Implement delayed fixed-target projection and readiness logging**

After `SetViewTarget(this)`, schedule `ValidateAndLogReady` on a short one-shot timer so the PlayerController has an active Camera. Use:

```cpp
FVector2D ScreenPosition;
int32 ViewportX = 0;
int32 ViewportY = 0;
PlayerController->GetViewportSize(ViewportX, ViewportY);
const bool bProjected = PlayerController->ProjectWorldLocationToScreen(
    Phase1DirectLighting::ReceiverTarget,
    ScreenPosition,
    true);
const FIntPoint TargetPixel(
    FMath::RoundToInt(ScreenPosition.X),
    FMath::RoundToInt(ScreenPosition.Y));
```

Require `bProjected`, viewport `1280×1080`, and an in-bounds target. Log Phase, ShadowMode, all object transforms, Spot parameters, target world/screen position, viewport, and `Stage=Ready`.

Immediately after the Ready log, call `SchedulePixCaptureIfRequested()`. Do not schedule capture after any failed baseline or projection check.

- [ ] **Step 8: Run Automation Tests until green**

Run the Editor build and Automation Test commands from Task 2.

Expected: Registry, Phase0, Phase1 component, and Shadow parsing tests report Success. Do not claim viewport or GPU validation from this run.

- [ ] **Step 9: Add parameterized run and runtime-verification tools**

Create `Tools/RunRenderPipelinePhase.ps1` accepting `ProjectRoot`, `Phase`, `ShadowMode`, `Visible`, and `LogName`. It launches `UnrealEditor.exe` with a hidden window for automated logs and a normal window only when `-Visible` is specified.

The launch contract is:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$EngineRoot = $env:UE_ENGINE_ROOT,
    [ValidateSet('Phase0','Phase1')][string]$Phase = 'Phase0',
    [ValidateSet('On','Off')][string]$ShadowMode = 'On',
    [switch]$Visible,
    [string]$LogName = 'RenderPipelinePhase.log'
)

if ([string]::IsNullOrWhiteSpace($EngineRoot)) {
    throw 'EngineRoot is required; pass -EngineRoot or set UE_ENGINE_ROOT.'
}
$project = Join-Path $ProjectRoot 'RenderPipelineLab.uproject'
$editor = Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor.exe'
if (-not (Test-Path -LiteralPath $editor)) { throw "UnrealEditor missing: $editor" }
$arguments = @(
    $project, '-game', '-dx12', '-windowed', '-ResX=1280', '-ResY=1080',
    "-RenderPipelinePhase=$Phase", '-log', "-Log=$LogName"
)
if ($Phase -eq 'Phase1') { $arguments += "-Phase1Shadow=$ShadowMode" }
$windowStyle = if ($Visible) { 'Normal' } else { 'Hidden' }
Start-Process -FilePath $editor `
  -ArgumentList $arguments -WindowStyle $windowStyle -PassThru
```

Create `Tools/VerifyPhase1Runtime.ps1` that parses two logs and asserts:

```text
Phase=Phase1 Stage=Ready
ShadowMode=On / Off
Viewport=1280x1080
identical TargetWorldPosition
identical integer TargetScreenPosition
all required CVar values
```

It must reject missing Ready, mismatched coordinates, wrong resolution, or any baseline mismatch.

Implement exact coordinate extraction with named captures:

```powershell
$pattern = 'TargetWorldPosition=(?<World>[^\r\n]+).*TargetScreenPosition=\((?<X>\d+),(?<Y>\d+)\)'
$onMatch = [regex]::Match($onLog, $pattern, 'Singleline')
$offMatch = [regex]::Match($offLog, $pattern, 'Singleline')
if (-not $onMatch.Success -or -not $offMatch.Success) { throw 'Target coordinates missing.' }
if ($onMatch.Groups['World'].Value -ne $offMatch.Groups['World'].Value) { throw 'Target world position differs.' }
if ($onMatch.Groups['X'].Value -ne $offMatch.Groups['X'].Value -or
    $onMatch.Groups['Y'].Value -ne $offMatch.Groups['Y'].Value) { throw 'Target screen position differs.' }
```

- [ ] **Step 10: Run hidden D3D12 Shadow On/Off smoke tests**

Run Phase1 On and Off separately with `RunRenderPipelinePhase.ps1`, wait for Ready, then stop only the exact returned process ID. Verify the logs with `VerifyPhase1Runtime.ps1`.

Expected: both processes reach Ready; target coordinates match exactly; only ShadowMode and `CastShadows` differ in the experiment contract.

- [ ] **Step 11: Run one visible smoke test and freeze scene constants**

Launch Phase1 Shadow On with `-Visible`. Confirm the Camera sees Box, Plane, and the Box shadow over the logged receiver target. If framing is wrong, adjust only the named constants, rerun On and Off, and repeat runtime verification. Once accepted, copy exact constants and target pixel into `docs/phase1-direct-lighting.md` and do not change them during evidence capture.

- [ ] **Step 12: Build Game Target, Cook, and Stage for PIX**

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  RenderPipelineLab Win64 Development `
  '-Project=H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -WaitMutex -NoHotReloadFromIDE

& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\RunUAT.bat' BuildCookRun `
  '-project=H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -noP4 -platform=Win64 -clientconfig=Development `
  -target=RenderPipelineLab -cook '-map=/Engine/Maps/Entry' `
  -stage -pak -archive `
  '-archivedirectory=H:\Unreal\Workspace\RenderPipelineLab\Saved\StagedPIX' `
  -utf8output
```

Expected: build and stage exit `0`; staged executable and PDB exist under `Saved` and remain ignored.

- [ ] **Step 13: Capture Phase1 Shadow On and Off with PIX**

Create `Tools/CapturePhase1Pix.ps1` to launch the staged executable through `pixtool.exe` twice. It accepts `ProjectRoot` and `PixToolPath`; `PixToolPath` defaults to `$env:PIX_TOOL_PATH` and is rejected when missing:

```text
Saved/Captures/PIX/Phase1_ShadowOn.wpix
Saved/Captures/PIX/Phase1_ShadowOff.wpix
```

Pass `-RenderPipelinePhase=Phase1`, the corresponding `-Phase1Shadow`, `-pixautocapture`, D3D12, Windowed, and 1280×1080. Export event CSVs and final-color PNGs. Captures remain ignored.

Use one helper invocation per mode:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$PixToolPath = $env:PIX_TOOL_PATH
)
if ([string]::IsNullOrWhiteSpace($PixToolPath) -or
    -not (Test-Path -LiteralPath $PixToolPath)) {
    throw 'PixToolPath is required; pass -PixToolPath or set PIX_TOOL_PATH.'
}
$pix = $PixToolPath
$stageRoot = Join-Path $ProjectRoot 'Saved\StagedPIX'
$stageWindows = Join-Path $stageRoot 'Windows'
$exe = Join-Path $stageWindows `
    'RenderPipelineLab\Binaries\Win64\RenderPipelineLab.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Current staged executable is missing: $exe"
}
foreach ($mode in @('On','Off')) {
    $capture = Join-Path $ProjectRoot "Saved\Captures\PIX\Phase1_Shadow$mode.wpix"
    $commandLine = "-dx12 -windowed -ResX=1280 -ResY=1080 -RenderPipelinePhase=Phase1 -Phase1Shadow=$mode -pixautocapture -log"
    $pixArgs = '--output=verbose launch "' + $exe +
        '" --working-directory="' + (Split-Path $exe -Parent) +
        '" --command-line="' + $commandLine +
        '" programmatic-capture save-capture "' + $capture + '"'
    $process = Start-Process -FilePath $pix -ArgumentList $pixArgs `
        -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "PIX capture failed for Shadow $mode." }
}
```

After both captures complete, run `VerifyPhase1Runtime.ps1` against the two staged-run logs. Expected: the same frozen target world/screen position and a valid baseline in both logs.

- [ ] **Step 14: Inspect and record runtime evidence**

For Shadow On, confirm actual events/resources for Base Pass, Shadow Depth, `ShadowProjectionOnOpaque`, Shadow Mask, `RenderLight Light::StandardDeferred`, and Scene Color. For Shadow Off, confirm the Spot Light remains in Standard Deferred while its corresponding Shadow Depth / Projection work is absent and unshadowed attenuation is used.

Record event names, resource names, target pixel, Shader permutation, and unresolved items in `docs/phase1-direct-lighting.md`. Mark source-only expectations separately from observed capture facts.

- [ ] **Step 15: Sync observed evidence back to the Phase1 Trace Cards**

Use the Obsidian CLI and Obsidian Markdown workflow to update only the runtime-evidence sections of:

```text
D:\IvanOneDriveCloud\ivan-ai-driven\862-UE 相关\50-直接光求解\041-Local Projected Shadow Mask：Shadow Depth 到 Screen Shadow Mask.md
D:\IvanOneDriveCloud\ivan-ai-driven\862-UE 相关\50-直接光求解\060-Standard Deferred Box 与 Plane：从 GBuffer 与 Shadow Mask 到 Scene Color.md
```

Record the actual executable, command line, CVar snapshot, target pixel, PIX file name, observed Event hierarchy, input/output resources, Shader permutation, Shadow On/Off differences, and remaining unknowns. Keep source facts and runtime observations in separate rows. Change the milestone from “运行时未验证” only if both captures satisfy the Trace Card.

Verify the two notes with `obsidian outline`, `git diff --check`, and an exact diff review. In `D:\IvanOneDriveCloud\ivan-ai-driven`, stage only those two notes, preserve unrelated files such as `060-Daily/2026-09-02.md`, commit with:

```powershell
git commit -m '补充直接光 Phase1 运行时证据'
git push origin master
```

- [ ] **Step 16: Update README and Phase documentation**

Create a concise `README.md` with project purpose, environment variables, build commands, Phase selection, and links to Phase docs. Move the current long Box workflow into `docs/phase0-static-box.md`, updating paths to the renamed project. Do not publish local captures.

- [ ] **Step 17: Commit Phase1 only after all local gates pass**

```powershell
git add -- 'Config' 'Source' 'Tools' 'README.md' 'docs/phase0-static-box.md' 'docs/phase1-direct-lighting.md'
pwsh -NoProfile -File '.\Tools\ValidateRepository.ps1' -RepositoryRoot . -TrackedOnly
git diff --cached --check
git commit -m 'feat: add phase1 direct lighting experiment'
```

Expected: commit contains source, config, tools, tests, and textual evidence only; no capture or generated file is tracked.

---

### Task 4: Add repository checks and publish verified `main`

**Files:**

- Create: `.github/workflows/repository-checks.yml`
- Modify: `Tools/ValidateRepository.ps1` only if CI reveals a portable parsing issue.

**Interfaces:**

- Consumes: locally verified Phase0/Phase1 commits and public empty GitHub repository.
- Produces: public `main` matching local HEAD; GitHub Actions repository checks.

- [ ] **Step 1: Add a failing workflow-layout assertion to the validator test**

Extend `TestValidateRepository.ps1` with a tracked-layout fixture that omits `RenderPipelineLab.uproject` and `.github/workflows/repository-checks.yml`, then invoke the validator with a new `-RequireProjectLayout` switch and expect failure.

Add this fixture before the test script's `finally` block:

```powershell
$layoutRoot = Join-Path $resolvedTemp 'LayoutFixture'
New-Item -ItemType Directory -Path $layoutRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $layoutRoot 'Source') | Out-Null
if ((Invoke-ValidatorProcess -Root $layoutRoot -RequireProjectLayout) -eq 0) {
    throw 'Incomplete project layout unexpectedly passed.'
}
```

Expected before Step 2: FAIL because `ValidateRepository.ps1` does not accept `-RequireProjectLayout` or does not reject the incomplete fixture.

- [ ] **Step 2: Implement `-RequireProjectLayout`**

Add required paths:

```powershell
# Add to the validator param block:
[switch]$RequireProjectLayout

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
        if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
            $failures.Add("Missing required path: $required")
        }
    }
}
```

When `-RequireProjectLayout` is set, fail once for each missing path. Rerun `TestValidateRepository.ps1`; expected PASS.

- [ ] **Step 3: Create GitHub Actions repository checks**

Create `.github/workflows/repository-checks.yml`:

```yaml
name: repository-checks
on:
  push:
  pull_request:
jobs:
  validate:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: false
      - name: Validate tracked tree
        shell: pwsh
        run: ./Tools/ValidateRepository.ps1 -RepositoryRoot . -TrackedOnly -RequireProjectLayout
      - name: Test validator
        shell: pwsh
        run: ./Tools/TestValidateRepository.ps1 -ValidatorPath ./Tools/ValidateRepository.ps1
```

- [ ] **Step 4: Run the CI commands locally**

```powershell
git add -- '.github/workflows/repository-checks.yml' `
  'Tools/ValidateRepository.ps1' 'Tools/TestValidateRepository.ps1'
pwsh -NoProfile -File '.\Tools\ValidateRepository.ps1' `
  -RepositoryRoot . -TrackedOnly -RequireProjectLayout
pwsh -NoProfile -File '.\Tools\TestValidateRepository.ps1' `
  -ValidatorPath '.\Tools\ValidateRepository.ps1'
git diff --check
```

Expected: all exit `0`.

- [ ] **Step 5: Commit CI**

```powershell
git diff --cached --check
git commit -m 'ci: add repository validation'
```

- [ ] **Step 6: Run final local completion gates**

Freshly run:

```text
repository validator
validator regression tests
RenderPipelineLab Win64 Debug build
Project.RenderPipelineLab Automation Tests
Phase0 smoke verification
Phase1 Shadow On runtime verification
Phase1 Shadow Off runtime verification
PIX Shadow On inspection
PIX Shadow Off inspection
git diff HEAD --check
git status --short
```

Expected: every required command passes; only ignored generated artifacts remain; no tracked change is pending.

- [ ] **Step 7: Configure the exact remote and verify it is still empty**

```powershell
gh repo view ivanfuland/render-pipeline-lab `
  --json nameWithOwner,visibility,isEmpty,url
git remote add origin https://github.com/ivanfuland/render-pipeline-lab.git
git remote -v
```

Expected: repository is Public and empty; `origin` exactly matches the approved URL. If `origin` already exists, verify it instead of replacing it.

- [ ] **Step 8: Push `main` and verify local/remote identity**

```powershell
git push -u origin main
$head = git rev-parse HEAD
git fetch origin main
$remote = git rev-parse origin/main
"HEAD=$head"
"ORIGIN_MAIN=$remote"
if ($head -ne $remote) { throw 'Remote main does not match local HEAD.' }
gh run list --repo ivanfuland/render-pipeline-lab --limit 5
```

Expected: push succeeds, hashes match, and the repository-checks workflow is queued or completed successfully.

---

## Plan Completion Checklist

- [ ] Every spec acceptance criterion maps to a Task step.
- [ ] No project file containing the current Android File Server token is ever staged before sanitization.
- [ ] Directory move uses exact validated absolute paths.
- [ ] Phase0 default behavior is covered by tests and smoke verification.
- [ ] Phase1 CPU contract, D3D12 viewport contract, and GPU resource contract are verified at the correct evidence layer.
- [ ] Scene constants are frozen before evidence capture.
- [ ] Public Git history contains no generated files, captures, credentials, or generated security tokens.
- [ ] GitHub `main` and local verified HEAD are identical.
