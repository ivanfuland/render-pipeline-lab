# RenderPipelineLab Monorepo Design

**Status:** Approved design, implementation not started

**Date:** 2026-09-02

**Target repository:** `https://github.com/ivanfuland/render-pipeline-lab`

**Current project:** `H:\Unreal\Workspace\test`

**Target project:** `H:\Unreal\Workspace\RenderPipelineLab`

## 1. Background

The existing UE 5.8.1 project is a C++-only renderer experiment harness. Its Game Target is already named `RenderPipelineLab`, but the directory, `.uproject`, Editor Target, Runtime Module, generated solution files, script paths, and configuration references still use `test`.

The current experiment creates a white static Box in C++ and supports transform, render-state rebuild, component destroy/create, Visual Studio breakpoints, and PIX automatic capture. This experiment becomes Phase0.

The next experiment implements the Direct Lighting vertical slice defined by:

- `D:\IvanOneDriveCloud\ivan-ai-driven\862-UE 相关\20-渲染系统分析\direct-lighting-principel\PRODUCT-DOC-v2.md` for Phase 1 scope and evidence policy;
- `D:\IvanOneDriveCloud\ivan-ai-driven\862-UE 相关\50-直接光求解\060-Standard Deferred Box 与 Plane：从 GBuffer 与 Shadow Mask 到 Scene Color.md` as the Phase1 runtime fact source.

The repository must support additional renderer experiments without duplicating the UE project, build configuration, packaging pipeline, or capture tools.

## 2. Goals

1. Rename the project directory and Unreal identifiers from `test` to `RenderPipelineLab`.
2. Convert the project into a single-project monorepo with a Phase Registry.
3. Preserve the existing white Box experiment as Phase0.
4. Add the Standard Deferred direct-lighting experiment as Phase1.
5. Preserve Visual Studio breakpoint, Automation Test, PIX, RenderDoc, and Nsight workflows.
6. Manage reproducible source, configuration, tools, tests, and documentation in GitHub.
7. Keep generated files, captures, PDBs, staged builds, and local caches outside Git.

## 3. Non-goals

- Do not include Unreal Engine source in the repository.
- Do not add Phase 2 renderer features such as VSM, Clustered Deferred, Forward Light Grid, Ray Traced Shadows, or MegaLights.
- Do not create one `.uproject` per Phase.
- Do not use one Runtime Module per Phase in the initial design.
- Do not commit PIX, RenderDoc, or Nsight capture files.
- Do not treat source markers or C++ breakpoints as proof of GPU Pass execution.
- Do not publish performance conclusions from the implementation task.

## 4. Constraints

| Constraint | Decision |
|---|---|
| Engine | UE 5.8.1 source build at `H:\Unreal\UnrealEngine` |
| Engine branch | `study-ue-5.8.1` |
| Engine commit | `71fe36aac5a8df5ccd66c763ffc902b29b6a9c43` |
| Platform | Windows 11, D3D12, desktop SM6 |
| Project model | One `.uproject`, one Runtime Module, multiple Phases |
| Phase selection | Explicit command-line argument; Phase0 is the compatibility default |
| Runtime evidence | GPU Capture confirms Pass, Shader, and resources; C++ breakpoints supplement CPU branch evidence |
| Repository | Public GitHub repository `ivanfuland/render-pipeline-lab` |
| Capture artifacts | Local only under `Saved\Captures` |
| Public-repository safety | Credentials, generated security tokens, captures, binaries, and private machine state never enter Git history |

## 5. Repository layout

```text
RenderPipelineLab/
├─ .github/
│  └─ workflows/
│     └─ repository-checks.yml
├─ Config/
├─ Content/
├─ Source/
│  ├─ RenderPipelineLab.Target.cs
│  ├─ RenderPipelineLabEditor.Target.cs
│  └─ RenderPipelineLab/
│     ├─ Core/
│     │  ├─ RenderPipelineLabGameMode.h
│     │  ├─ RenderPipelineLabGameMode.cpp
│     │  ├─ RenderPipelinePhaseActor.h
│     │  ├─ RenderPipelinePhaseActor.cpp
│     │  ├─ RenderPipelinePhaseRegistry.h
│     │  └─ RenderPipelinePhaseRegistry.cpp
│     ├─ Phases/
│     │  ├─ Phase0_StaticBox/
│     │  │  ├─ Phase0StaticBoxActor.h
│     │  │  └─ Phase0StaticBoxActor.cpp
│     │  └─ Phase1_DirectLighting/
│     │     ├─ Phase1DirectLightingActor.h
│     │     └─ Phase1DirectLightingActor.cpp
│     ├─ Tests/
│     ├─ RenderPipelineLab.Build.cs
│     ├─ RenderPipelineLab.h
│     └─ RenderPipelineLab.cpp
├─ Tools/
├─ docs/
│  ├─ phase0-static-box.md
│  ├─ phase1-direct-lighting.md
│  └─ superpowers/
│     ├─ specs/
│     └─ plans/
├─ RenderPipelineLab.uproject
├─ README.md
├─ .vsconfig
├─ .gitattributes
└─ .gitignore
```

`Content` remains available for future required assets. The initial Phase0 and Phase1 implementations use Engine basic shapes and C++-created components, so no project map is required.

`.gitattributes` routes future `.uasset` and `.umap` files through Git LFS. Git LFS availability is checked before an asset matching those patterns is staged. The current source-only Phases do not require LFS objects.

## 6. Naming migration

The migration renames all project-owned Unreal identifiers:

```text
H:\Unreal\Workspace\test
→ H:\Unreal\Workspace\RenderPipelineLab

test.uproject
→ RenderPipelineLab.uproject

Source\test
→ Source\RenderPipelineLab

testEditor.Target.cs
→ RenderPipelineLabEditor.Target.cs

Runtime Module: test
→ RenderPipelineLab

TEST_API
→ RENDERPIPELINELAB_API

/Script/test
→ /Script/RenderPipelineLab
```

`ActiveGameNameRedirects` retains redirects from `test` to `RenderPipelineLab`. Generated `.sln` and `.slnx` files are removed from source control and regenerated after the rename.

The migration is performed only after resolving the exact source and destination paths and confirming Unreal Editor, Visual Studio, Cook, and capture processes are not using the project directory.

## 7. Phase architecture

### 7.1 Game Mode

`ARenderPipelineLabGameMode` owns Phase selection and startup.

It reads:

```text
-RenderPipelinePhase=Phase0
-RenderPipelinePhase=Phase1
```

Phase0 is the default when the argument is omitted, preserving the current project behavior.

Unknown Phase IDs are startup errors. The Game Mode logs the invalid ID, spawns no Phase Actor, and requests process exit with a non-zero status. It does not silently start a different experiment.

### 7.2 Phase base class

`ARenderPipelinePhaseActor` defines the shared runtime contract:

- stable Phase ID;
- display name;
- startup and readiness logging;
- optional capture scheduling;
- common CVar logging utilities.

The base class does not contain Phase-specific scene components or renderer assumptions.

### 7.3 Registry

`FRenderPipelinePhaseRegistry` maps stable IDs to Actor classes:

```text
Phase0 → APhase0StaticBoxActor
Phase1 → APhase1DirectLightingActor
```

The initial implementation uses a static C++ registry. It avoids plugin discovery, asset registry dependencies, and configuration-driven class loading.

## 8. Phase0 compatibility contract

Phase0 contains the existing white static Box experiment.

The migration preserves:

- Engine Cube and Basic Shape Material;
- stable component tag used by conditional breakpoints;
- keys `1` through `4`;
- transform update;
- `MarkRenderStateDirty()`;
- component destroy and recreate;
- unique component generation names;
- `-pixautocapture` support;
- existing Automation Test assertions;
- existing renderer baseline settings.

Class names may change to reflect Phase0, but runtime logs keep an explicit Phase field so old and new evidence can be distinguished.

## 9. Phase1 Direct Lighting contract

The runtime design follows `060-Standard Deferred Box 与 Plane：从 GBuffer 与 Shadow Mask 到 Scene Color.md`.

### 9.1 Scene

`APhase1DirectLightingActor` creates:

```text
SceneRoot
├─ BoxCaster
├─ PlaneReceiver
├─ MovableSpotLight
└─ FixedCamera
```

| Object | Required properties |
|---|---|
| BoxCaster | Opaque Default Lit, non-Nanite, `CastShadow=true` |
| PlaneReceiver | Opaque Default Lit, non-Nanite, `CastShadow=false` |
| Spot Light | Movable, default Lighting Channel, no IES, no Light Function |
| Spot Light shape | Contact Shadow Length, Source Radius, and Source Length are zero |
| Camera | Fixed Transform and FOV; sees Box, Plane, and projected shadow region |

No Directional Light or Sky Light is created in Phase1.

All geometry, Light, Camera, and receiver-target values are named C++ constants. Initial values may be adjusted during the pre-evidence visual smoke test only. Once the Box shadow covers the receiver target and the Camera framing is accepted, the constants are frozen, documented in `docs/phase1-direct-lighting.md`, and remain identical for Shadow On and Shadow Off evidence runs.

### 9.2 Shadow variants

Formal evidence uses separate processes:

```text
-RenderPipelinePhase=Phase1 -Phase1Shadow=On
-RenderPipelinePhase=Phase1 -Phase1Shadow=Off
```

The two runs differ only in Spot Light `CastShadows`. Interactive toggles are not accepted as Trace Card evidence.

### 9.3 Fixed receiver target

Phase1 defines a stable Plane world position inside the Box shadow region. After the Camera becomes active, the Actor projects this point into the 1280×1080 viewport and logs:

```text
Phase=Phase1
ShadowMode=On|Off
TargetWorldPosition=(...)
TargetScreenPosition=(...)
Viewport=1280x1080
Stage=Ready
```

The Shadow On and Shadow Off runs must report the same target screen position.

The D3D12 runtime verifier additionally requires:

- the target screen point is inside the 1280×1080 viewport;
- Shadow On and Shadow Off produce the same integer target coordinate;
- the Shadow On capture places the target inside the Box shadow region;
- the Shadow Off capture removes the corresponding projected-shadow attenuation while preserving Surface, Light, Camera, and material inputs.

### 9.4 Runtime boundary

| Field | Phase1 value |
|---|---|
| OS / RHI | Windows 11 / D3D12 |
| Feature Level / Shader Model | Desktop SM6; log actual Feature Level |
| Shading Path | Standard Deferred; `r.ForwardShading=0` |
| Clustered Deferred | `r.UseClusteredDeferredShading_ToBeRemoved=0`; log project enable CVar |
| Scalability | Epic (`3`); log the explicit quality-group snapshot |
| Shadow | Traditional Shadow Map + PCF |
| VSM | `r.Shadow.Virtual.Enable=0` |
| Filter | `r.Shadow.FilterMethod=0` |
| Whole-scene cache | `r.Shadow.CacheWholeSceneShadows=0` |
| Resolution | 1280×1080 Windowed; Dynamic Resolution Off |
| Disabled paths | Nanite, Substrate, MegaLights, RT, Lumen GI/Reflections, Distance Field, Static Lighting |

Phase1 validates the required boundary before entering `Stage=Ready`. Missing or mismatched values are explicit startup errors.

The project configuration sets the required quality level before launch. Phase1 does not silently repair mismatched project or read-only Renderer settings at runtime; it reports the mismatch and withholds `Stage=Ready`.

### 9.5 CVar snapshot

At minimum, Phase1 logs:

```text
r.ForwardShading
r.UseClusteredDeferredShading_ToBeRemoved
r.ClusteredDeferredShading.EnableForProject
r.Shadow.Virtual.Enable
r.Shadow.FilterMethod
r.Shadow.CacheWholeSceneShadows
r.Nanite.ProjectEnabled
r.Substrate
r.MegaLights.Allowed
r.RayTracing
r.DynamicGlobalIlluminationMethod
r.ReflectionMethod
r.GenerateMeshDistanceFields
r.AllowStaticLighting
sg.ResolutionQuality
sg.ViewDistanceQuality
sg.AntiAliasingQuality
sg.ShadowQuality
sg.GlobalIlluminationQuality
sg.ReflectionQuality
sg.PostProcessQuality
sg.TextureQuality
sg.EffectsQuality
sg.FoliageQuality
sg.ShadingQuality
sg.LandscapeQuality
```

The Phase1 evidence baseline expects `sg.ResolutionQuality=100` and every other supported quality group above to report `3` (Epic). Missing groups are logged as missing and reviewed against the UE 5.8.1 platform configuration rather than treated as an implicit pass.

## 10. Evidence workflow

### 10.1 C++ breakpoints

Phase1 documents and exercises these UE 5.8.1 entry points:

```text
RenderBasePass
GatherAndSortLights
CreateDynamicShadows
CreateWholeSceneProjectedShadow
RenderShadowDepthMaps
RenderDeferredShadowProjections
RenderShadowProjections
RenderLight
```

C++ breakpoint evidence confirms CPU branch execution and relevant object state.

### 10.2 GPU Capture

The Shadow On and Shadow Off captures inspect:

```text
Base Pass
→ ShadowDepths
→ ShadowProjectionOnOpaque
→ ShadowMaskTexture
→ RenderLight Light::StandardDeferred
→ Scene Color
```

The capture records actual Event hierarchy, Shader permutation, GBuffer, Scene Depth, Shadow Depth, Shadow Mask, Deferred Light inputs, and Scene Color before/after contribution at the fixed target pixel.

GPU Capture is the evidence for actual Pass, Shader, and resource execution. Source `RDG_EVENT_NAME` strings are only source facts.

After both captures pass, observed evidence is recorded in `docs/phase1-direct-lighting.md` and synchronized back to the runtime-evidence sections of the Obsidian `041` and `060` Trace Cards. Capture binaries stay local; only textual evidence is committed.

## 11. Tests and verification

### 11.1 Automation Tests

- Registry resolves Phase0 and Phase1.
- Unknown Phase IDs fail explicitly.
- Phase0 retains its existing component lifecycle behavior.
- Phase1 creates all required components.
- Phase1 Box and Plane shadow flags are correct.
- Phase1 Spot Light is Movable and has the required feature settings.
- Shadow On and Shadow Off set only `CastShadows` differently.
- Target world position is a stable named constant.

NullRHI Automation Tests do not claim to validate a real viewport, target screen coordinate, Shadow Pass, or GPU resource. Target projection is verified by the D3D12 runtime smoke test after the fixed Camera is active.

### 11.2 Baseline tools

The existing PowerShell verifier is generalized to validate common settings and Phase-specific settings. Scripts accept `-ProjectRoot` and do not embed the old `test` path.

### 11.3 Build and runtime checks

1. Generate project files.
2. Build `RenderPipelineLabEditor Win64 Development`.
3. Run `Project.RenderPipelineLab` Automation Tests under NullRHI where supported.
4. Launch Phase0 and verify existing logs and actions.
5. Launch Phase1 Shadow On and Shadow Off at 1280×1080.
6. Validate both Phase1 logs, exact fixed target coordinates, and the runtime boundary.
7. Build the `RenderPipelineLab` Game Target.
8. Cook and stage only when required for PIX validation.
9. Capture and inspect Shadow On and Shadow Off.

## 12. Git and GitHub management

The empty public repository `ivanfuland/render-pipeline-lab` uses `main`.

The migration preserves reviewable history:

```text
docs: add RenderPipelineLab monorepo design
docs: add RenderPipelineLab implementation plan
chore: archive original render pipeline probe
refactor: rename project and add phase registry
feat: add phase1 direct lighting experiment
ci: add repository validation
```

The design commit is reviewed before implementation. The first implementation commit records the original source/configuration/tooling baseline without generated files. The rename commit then allows Git to detect project and module renames.

Because the remote repository is Public, the baseline commit is a sanitized baseline. Before any project file is staged, the Android File Server `SecurityToken` currently present in `Config\DefaultEngine.ini` is removed and the related local-only settings are reviewed. The original generated token is never committed, even temporarily, because deleting it in a later commit would not remove it from Git history.

Tracked content includes:

- `.uproject`;
- `Source`;
- `Config`;
- `Tools`;
- `.vsconfig`;
- required `Content`;
- tests;
- README and docs;
- repository checks.

Ignored content includes:

- `.vs`;
- `Binaries`;
- `DerivedDataCache`;
- `Intermediate`;
- `Saved`;
- `.sln` and `.slnx`;
- `Build/Windows/FileOpenOrder`;
- Cook and Stage output;
- PIX, RenderDoc, and Nsight captures;
- PDBs and logs;
- `Content/Developers`.

The ignore and attributes rules are installed before the sanitized baseline is staged. A staged-tree scan rejects common credential names and values, including `SecurityToken`, access tokens, API keys, and private-key material.

Before the first push, the staged tree is scanned for tokens, generated files, capture files, and machine-specific sensitive data. Local absolute paths in reusable scripts are replaced with parameters or documented examples.

## 13. GitHub Actions boundary

The public GitHub runner does not have the custom UE 5.8.1 source build. CI therefore performs repository-level checks only:

- generated directory rejection;
- capture and binary artifact rejection;
- credential and generated security-token rejection;
- expected project/module/Target naming checks;
- Registry and Phase source layout checks;
- Markdown and PowerShell parsing where tooling is available.

Full Editor Build, Automation Tests, Cook, and GPU Capture remain local verification gates.

## 14. Migration safety and rollback

1. Confirm exact resolved source and destination paths.
2. Confirm destination does not exist.
3. Confirm Unreal Editor, Visual Studio, UBT, UAT, Cook, and capture processes are not using the project.
4. Install ignore/attributes rules and remove generated security tokens before staging.
5. Create the sanitized original baseline Git commit before renaming the directory.
6. Rename the directory as one recoverable filesystem move.
7. Do not delete the original project state through reset or cleanup commands.
8. If rename or build validation fails, use the baseline commit and the renamed directory history to restore source/configuration files.
9. Generated outputs can be regenerated and are never the rollback source.

## 15. Acceptance criteria

The implementation is complete only when:

1. The project resides at `H:\Unreal\Workspace\RenderPipelineLab`.
2. Project, Module, Editor Target, Game Target, API macro, and Script paths consistently use `RenderPipelineLab`.
3. The Phase Registry selects Phase0 by default and Phase1 explicitly.
4. Phase0 preserves its current component lifecycle and capture behavior.
5. Phase1 implements the exact `060` scene and runtime boundary.
6. Phase1 Shadow On and Shadow Off are separate-process runs differing only in `CastShadows`.
7. Scene constants are frozen and documented before evidence capture.
8. Both runs report the same in-viewport integer target screen coordinate.
9. Automation Tests pass without claiming GPU or viewport coverage under NullRHI.
10. Editor and Game Targets build successfully.
11. Phase0 smoke verification passes.
12. Phase1 Shadow On and Shadow Off D3D12 runtime verification passes.
13. Two GPU captures confirm the expected Standard Deferred and Local Projected Shadow resource chains.
14. The observed Shadow On/Off evidence is synchronized to the `041` and `060` Trace Cards without merging source facts and runtime observations.
15. Generated outputs, captures, credentials, and generated security tokens are excluded from Git history.
16. GitHub `main` matches the locally verified commit.

## 16. Implementation boundary

This document defines the approved design. It does not itself authorize unreviewed changes beyond creating and committing this specification. Implementation starts only after the user reviews this file and approves the subsequent implementation plan.
