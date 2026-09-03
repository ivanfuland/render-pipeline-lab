# RenderPipelineLab

RenderPipelineLab 是一个 UE5.8.1 Renderer 实验工程。工程使用单一 `.uproject` 和 Runtime Module，通过 Phase Registry 选择独立实验，统一复用构建、断点、Automation Test 和 GPU Capture 工具链。

## 当前 Phase

| Phase | 内容 | 状态 |
|---|---|---|
| Phase0 | 普通非 Nanite Box 从 Component 到 GPU Draw 的生命周期实验 | Build、Automation Test、D3D12 Ready 已验证 |
| Phase1 | Box / Plane / Movable Spot Light 的 Standard Deferred 直接光实验 | Debug Build、Automation Test、Shadow On/Off D3D12 Ready 与 PIX 代表路径已验证；像素级中间值待补充 |

## 环境

- Unreal Engine 5.8.1 源码版
- Windows 11 / D3D12 / SM6
- 本机使用的 Engine Commit：`71fe36aac5a8df5ccd66c763ffc902b29b6a9c43`

可复用脚本不依赖固定工程路径。建议设置：

```powershell
$env:UE_ENGINE_ROOT = 'H:\Unreal\UnrealEngine'
$env:PIX_TOOL_PATH = 'C:\Program Files\Microsoft PIX\2603.25\pixtool.exe'
```

## 构建

```powershell
& "$env:UE_ENGINE_ROOT\Engine\Build\BatchFiles\Build.bat" `
  RenderPipelineLab Win64 Debug `
  "$PWD\RenderPipelineLab.uproject" `
  -WaitMutex
```

`RenderPipelineLab Win64 Debug` 是最终构建与原生断点验证目标。NullRHI Automation Test 使用 Unreal Editor 作为宿主；首次搭建测试环境时可额外构建 `RenderPipelineLabEditor Win64 Development`，但它不替代最终 Debug 构建。

## 调试环境 Profile

工程把 Debug 调试拆成两个独立环境，避免在 VS 的 `.vcxproj.user` 中反复切换路径：

| Profile | 数据布局 | 用途 |
|---|---|---|
| Cooked Sandbox | `Saved/Cooked/Windows` loose files | 高频 C++、Renderer 断点迭代 |
| Staged Debug | `Saved/StagedDebug/Windows` Pak / staged layout | 完整包体、配置、启动期和部署布局验证 |

两个 Debug 环境共用两种调试方式：

| DebugMode | 主要参数 | 用途 |
|---|---|---|
| `ControlFlow` | `-onethread -norhithread` | 只观察函数顺序和局部变量，不记录真实线程归属 |
| `ThreadBoundary` | `-noperfthreads` + 目标链路 CVar | 保留 GT、RT、RHI 职责边界，减少 Worker 跳转 |

`ThreadBoundary` 是默认模式。Debug 专用 CVar 由启动脚本通过本次进程的 `-ExecCmds` 注入，不写入 `DefaultEngine.ini`，因此不会进入 Staged PIX Development 性能基线。

调试参数的唯一事实源是 `Tools/Scripts/DebugProfileSupport.ps1`。`Tools/Scripts/SyncVsDebugProfile.ps1` 使用同一函数生成 VS `Debug | x64` 的 `.vcxproj.user` 参数；该文件是忽略入库的本机副本，不手工维护。

准备 Cooked Sandbox：

```powershell
./Tools/Scripts/PrepareCookedSandbox.ps1 `
  -ProjectRoot $PWD `
  -EngineRoot $env:UE_ENGINE_ROOT `
  -Iterative
```

Prepare 完成后会自动把默认 `ThreadBoundary / Phase1 / Shadow On` 同步到 VS。重新生成 Visual Studio 工程文件后，也可以单独执行：

```powershell
./Tools/Scripts/SyncVsDebugProfile.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On `
  -DebugMode ThreadBoundary
```

Visual Studio 已打开时，执行同步后重新加载 RenderPipelineLab 项目或重开 Solution。

只改 C++ 时可以跳过 Prepare，直接在 VS 构建 `Debug | x64`。修改材质、地图或 Shader 编译配置后再 Cook。

启动 Cooked Sandbox：

```powershell
./Tools/Scripts/StartCookedSandboxDebug.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On `
  -DebugMode ThreadBoundary
```

只需要连续观察函数顺序时改用：

```powershell
./Tools/Scripts/StartCookedSandboxDebug.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On `
  -DebugMode ControlFlow
```

准备完整 Staged Debug：

```powershell
./Tools/Scripts/PrepareStagedDebug.ps1 `
  -ProjectRoot $PWD `
  -EngineRoot $env:UE_ENGINE_ROOT
```

启动并等待 VS Attach：

```powershell
./Tools/Scripts/StartStagedDebug.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On `
  -DebugMode ThreadBoundary `
  -WaitForAttach
```

脚本会输出 DebugMode、唯一 PID、EXE、Content Root 和当前 Profile 的实际日志路径。Cooked Sandbox 日志位于其 sandbox 内，Staged Debug 日志位于 staged project 的 `Saved/Logs`。VS 的 F5 保留给 Cooked Sandbox `ThreadBoundary`；Staged Debug 使用 `-WaitForAttach` 后从 `Debug → Attach to Process` 连接。Development `Saved/StagedPIX` 不注入 DebugMode CVar，只用于 GPU Capture 与性能基线。

调整公共参数或 DebugMode 时只修改 `Tools/Scripts/DebugProfileSupport.ps1`，随后运行 `Tools/Scripts/SyncVsDebugProfile.ps1`。启动脚本与 VS F5 均由该事实源生成参数。

## BAT 快捷入口

BAT 入口放在 `Tools/`，PowerShell 实现统一放在 `Tools/Scripts/`：

| BAT | 用途 |
|---|---|
| `StartCookedSandboxDebug.bat` | 启动 Cooked Sandbox Debug |
| `StartStagedDebug.bat` | 启动 Staged Debug 并等待 VS Attach |
| `PrepareCookedSandbox.bat` | Build Debug、增量 Cook，并同步 VS F5 |
| `PrepareStagedDebug.bat` | Build/Cook/Stage/Pak Staged Debug |
| `SyncVsDebugProfile.bat` | 只同步 VS `Debug | x64` 参数 |

启动和同步 BAT 接收三个可选位置参数：

```text
DebugMode Phase ShadowMode
```

不传参数时使用 `ThreadBoundary Phase1 On`。示例：

```bat
Tools\StartCookedSandboxDebug.bat ControlFlow Phase1 On
Tools\StartStagedDebug.bat ThreadBoundary Phase1 On
Tools\SyncVsDebugProfile.bat ThreadBoundary Phase1 Off
```

Prepare BAT 从 `%UE_ENGINE_ROOT%` 读取引擎路径。BAT 只转发参数给对应 `.ps1`，不保存 CVar；PowerShell 失败时返回相同错误码并暂停显示错误。

## Automation Test

```powershell
& "$env:UE_ENGINE_ROOT\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" `
  "$PWD\RenderPipelineLab.uproject" `
  -Unattended -NoSplash -NullRHI `
  '-ExecCmds=Automation RunTests Project.RenderPipelineLab;Quit' `
  '-TestExit=Automation Test Queue Empty'
```

NullRHI 只验证 CPU 与组件合同。Viewport、Shadow Pass、Shader 和 GPU 资源由 D3D12 运行与 GPU Capture 验证。

Debug Game 使用实验专用 Player Controller：鼠标指针保持可见，Viewport Capture 为 `NoCapture`，Mouse Lock 为 `DoNotLock`，便于在游戏窗口与 VS 之间切换和下断点。

## 运行 Phase

```powershell
./Tools/Scripts/RunRenderPipelinePhase.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase0
```

```powershell
./Tools/Scripts/RunRenderPipelinePhase.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On

./Tools/Scripts/RunRenderPipelinePhase.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode Off
```

Phase1 的正式证据使用两个独立进程，两轮只改变 Spot Light 的 `CastShadows`。

## 文档

- [Phase0 静态 Box](docs/phase0-static-box.md)
- [Phase1 Direct Lighting](docs/phase1-direct-lighting.md)
- [Monorepo Design](docs/superpowers/specs/2026-09-02-render-pipeline-lab-monorepo-design.md)
- [Implementation Plan](docs/superpowers/plans/2026-09-02-render-pipeline-lab-monorepo.md)

## Git 边界

Git 管理 Source、Config、Tools、测试和文档。以下内容不提交：

- `Binaries`、`Intermediate`、`DerivedDataCache`、`Saved`；
- `.sln` / `.slnx`、PDB 和日志；
- PIX、RenderDoc、Nsight Capture；
- `Content/Developers`；
- 自动生成的安全令牌和本机凭据。

`.uasset` 与 `.umap` 使用 Git LFS。当前 Phase0 / Phase1 使用 Engine Basic Shapes，由 C++ 创建场景，不依赖项目地图资产。
