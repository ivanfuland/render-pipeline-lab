# Phase0：UE 5.8.1 静态 Box 渲染链路实验

## 目标

本工程用于跟踪一个普通非 Nanite `UStaticMeshComponent` 从 Game Thread 到 Render Thread、Mesh Draw Command、RHI、D3D12 Command List 和 GPU Draw 的实际路径。

固定基线：

- UE 5.8.1 源码版：`H:\Unreal\UnrealEngine`
- 工程：`H:\Unreal\Workspace\RenderPipelineLab`
- DX12、SM6、Deferred Shading
- Nanite、Lumen、Hardware Ray Tracing、Substrate、VSM、Static Lighting 关闭
- Auto Exposure 和 Bloom 关闭
- Box 材质：`/Engine/BasicShapes/BasicShapeMaterial`，Opaque Surface，纹理依赖数为 0
- 保持 Render Thread、RHI Thread 和并行 Mesh Draw 的正常配置

## 构建与自动化测试

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  RenderPipelineLabEditor Win64 Development `
  'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -WaitMutex -NoHotReloadFromIDE
```

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor-Cmd.exe' `
  'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -Unattended -NoSplash -NullRHI `
  '-ExecCmds=Automation RunTests Project.RenderPipelineProbe;Quit' `
  '-TestExit=Automation Test Queue Empty' `
  '-Log=RenderPipelineProbeTests.log'
```

通过标准：`Saved\Logs\RenderPipelineProbeTests.log` 包含：

```text
Test Completed. Result={Success} Name={ActorLifecycle}
```

## 启动 Demo

```powershell
$DemoProcess = Start-Process `
  -FilePath 'H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor.exe' `
  -ArgumentList @(
    'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject',
    '-game',
    '-dx12',
    '-windowed',
    '-ResX=1280',
    '-ResY=720',
    '-log',
    '-Log=RenderPipelineLab.log'
  ) `
  -WindowStyle Normal `
  -PassThru

$DemoProcess.Id
```

运行日志：`H:\Unreal\Workspace\RenderPipelineLab\Saved\Logs\RenderPipelineLab.log`。

基线检查：

```powershell
& 'H:\Unreal\Workspace\RenderPipelineLab\Tools\VerifyRenderPipelineBaseline.ps1' `
  -ProjectRoot 'H:\Unreal\Workspace\RenderPipelineLab' `
  -LogPath 'H:\Unreal\Workspace\RenderPipelineLab\Saved\Logs\RenderPipelineLab.log'
```

## 输入动作

| 按键 | 动作 | 预期日志 |
|---|---|---|
| `1` | 在初始位置与 Y 轴偏移位置间切换 | `Stage=Transform` |
| `2` | `MarkRenderStateDirty()` | `Stage=RenderStateDirty` |
| `3` | 销毁 Box Component | `Stage=Destroy`，画面中 Box 消失 |
| `4` | 创建并注册新 Box Component | `Stage=Create`，Box 回到初始位置；组件名依次使用 `_0`、`_1` 后缀避免复用待 GC 的 UObject 名称 |

高频断点启用前先用按键建立窄时间窗口。例如验证注册期时先按 `3`，启用创建相关断点，再按 `4`。

## Visual Studio Attach

1. 用上述命令独立启动 Demo。
2. 在 Visual Studio 选择 `Debug > Attach to Process`。
3. 选择命令返回 PID 对应的 `UnrealEditor.exe`，Code Type 使用 Native。
4. 首先只启用组件层断点，确认对象后再逐步启用 Renderer、RHI 和 D3D12 高频断点。
5. Development Editor 中局部变量受优化影响时先使用调用栈、`this`、函数参数和日志；确有需要时再构建 Debug Editor。

### 创建与场景注册

| 阶段 | 函数 | UE 5.8.1 文件与行号 | 预期执行域 | 触发动作 | 条件建议 | 记录证据 |
|---|---|---|---|---|---|---|
| 创建 Render State | `UPrimitiveComponent::CreateRenderState_Concurrent` | `Engine/Private/Components/PrimitiveComponent.cpp:620` | Game Thread | 启动或 `4` | `ComponentTags` 包含 `RenderPipelineProbe.Box` | 调用者、Scene 是否有效、线程名 |
| 创建 Proxy | `UStaticMeshComponent::CreateSceneProxy` | `Engine/Private/StaticMeshSceneProxy.cpp:2986` | Game Thread | 启动或 `4` | `GetName()` 包含 `RenderPipelineProbe_Box` | 返回的 `FStaticMeshSceneProxy`、Mesh、Material |
| 加入 FScene | `FScene::AddPrimitive(UPrimitiveComponent*)` | `Renderer/Private/RendererScene.cpp:1341` | Game Thread 入口 | 启动或 `4` | Primitive Tag | Scene、Primitive、后续排队位置 |
| Render Thread 注册 | `FScene::AddPrimitiveSceneInfo_RenderThread` | `Renderer/Private/RendererScene.cpp:1069` | Render Thread | 启动或 `4` | 先由上层断点取得 `PrimitiveSceneInfo` 地址 | SceneInfo、Proxy、Scene 索引 |
| 产生 Static Mesh | `FStaticMeshSceneProxy::DrawStaticElements` | `Engine/Private/StaticMeshSceneProxy.cpp:1402` | Render Thread / Renderer Task | 启动或 `4` | Owner Name 对应实验 Actor | LOD、Section、Material、PDI 调用 |
| 收集 Static Mesh | `FPrimitiveSceneInfo::AddStaticMeshes` | `Renderer/Private/PrimitiveSceneInfo.cpp:1604` | Render Thread / Renderer Task | 启动或 `4` | SceneInfos 中包含已记录地址 | `FStaticMeshBatch` 数量与 MeshBatch |
| 缓存命令 | `FPrimitiveSceneInfo::CacheMeshDrawCommands` | `Renderer/Private/PrimitiveSceneInfo.cpp:583` | Render Thread / Renderer Task | 启动、`2` 或 `4` | SceneInfos 中包含已记录地址 | Pass、State Bucket、Cached Command Info |

### Base Pass 工作生成

| 阶段 | 函数 | UE 5.8.1 文件与行号 | 预期执行域 | 触发方式 | 记录证据 |
|---|---|---|---|---|---|
| Base Pass 过滤 | `FBasePassMeshProcessor::AddMeshBatch` | `Renderer/Private/BasePassRendering.cpp:1922` | Render Thread / Renderer Task | `2` 或 `4` 后的注册阶段 | `MeshBatch`、Material、Primitive Proxy、StaticMeshId |
| 构建模板 | `FMeshPassProcessor::BuildMeshDrawCommands` | `Renderer/Public/MeshPassProcessor.inl:57` | Render Thread / Renderer Task | `2` 或 `4` | Pass Shader、Pipeline State、Shader Bindings、Draw 参数 |
| Cached/Dynamic 分流 | `FDrawCommandRelevancePacket::AddCommandsForMesh` | `Renderer/Private/SceneVisibility.cpp:1269` | Renderer Task | 稳定帧 | Cached Command Info、目标 Pass、Visible Command |
| Per-view Pass Setup | `FSceneRenderer::SetupMeshPass` | `Renderer/Private/SceneRendering.cpp:5010` | Render Thread / Renderer Task | 稳定帧 | `EMeshPass::BasePass`、排序和 Instance Culling 输入 |
| 提交 Draw | `FMeshDrawCommand::SubmitDraw` | `Renderer/Private/MeshPassProcessor.cpp:1477` | Renderer Task / Render Thread | 稳定帧 | Pipeline、Bindings、Index Buffer、Draw 参数、调用的 RHI Draw |

UE 5.8.1 还把部分路径拆成 `SubmitDrawBegin`（`MeshPassProcessor.cpp:1248`）与 `SubmitDrawEnd`（`MeshPassProcessor.cpp:1332`）。若 `SubmitDraw` 因 Instance Culling 路径没有覆盖目标 Draw，改在 Begin/End 两处记录。

### Transform、重建与销毁对照

| 动作 | 函数 | UE 5.8.1 文件与行号 | 判断 |
|---|---|---|---|
| `1` | `UPrimitiveComponent::SendRenderTransform_Concurrent` | `Engine/Private/Components/PrimitiveComponent.cpp:655` | 应命中 Transform 更新路径 |
| `1` | `FScene::UpdatePrimitiveTransform(UPrimitiveComponent*)` | `Renderer/Private/RendererScene.cpp:1603` | 应更新 Scene/Bounds；通常不重建 Cached Draw Command |
| `2` | `UActorComponent::MarkRenderStateDirty` | `Engine/Private/Components/ActorComponent.cpp:2693` | 明确的 Render State Dirty 入口 |
| `2`、`3` | `UPrimitiveComponent::DestroyRenderState_Concurrent` | `Engine/Private/Components/PrimitiveComponent.cpp:866` | 移除旧 Renderer 表示 |
| `2`、`3` | `FScene::RemovePrimitive(UPrimitiveComponent*)` | `Renderer/Private/RendererScene.cpp:2001` | 从 Renderer Scene 移除 |
| `2` | `CreateRenderState_Concurrent`、`CreateSceneProxy`、`CacheMeshDrawCommands` | 见创建表 | 应再次命中 |
| `3` | 创建相关断点 | 见创建表 | 不应在只销毁动作中再次命中 |

### RHI 与 D3D12

| 阶段 | 函数 | UE 5.8.1 文件与行号 | 预期执行域 | 记录证据 |
|---|---|---|---|---|
| RHI Submit 编排 | `FRHICommandListExecutor::Submit` | `RHI/Private/RHICommandList.cpp:1470` | Render Thread / RHI 调度域 | Submit Flags、Additional Command Lists、Completion Event |
| RHI Translate | `FRHICommandListExecutor::FTranslateState::Translate_ExecuteCommandList` | `RHI/Private/RHICommandList.cpp:1184` | RHI Thread 或 Task Worker | 当前 FRHI Command List、调用栈、线程名 |
| D3D12 Queue Submit | `FD3D12Queue::ExecuteCommandLists` | `D3D12RHI/Private/Windows/WindowsD3D12Device.cpp:2468` | D3D12 Submission Thread 或 RHI 执行域 | Queue Type、Command List 数量、Fence/Payload 上下文 |

这些断点是帧级高频入口，不能仅靠 Box 名全局过滤。先从组件、Proxy 和 Base Pass 窄窗口取得实际调用栈，再短时启用 RHI/D3D12 断点。

## RenderDoc 1.45

RenderDoc 与 Visual Studio、Nsight 分开运行。

### 运行后 Inject 的边界

`renderdoccmd inject --PID` 可以把 `renderdoc.dll` 注入已经运行的进程，但此时 D3D12 Device 和 Queue 已创建，现有对象没有被 RenderDoc 包装，F12 不会生成有效捕获。因此，本实验不能使用“普通 Demo 启动完成后再 Inject”的方式抓 D3D12 稳定帧。

采用以下方式独立启动 Demo，只在启动阶段安装 Hook；实际抓帧仍等到 `Stage=Ready` 后执行，不采集启动帧：

```powershell
$DemoProcess = Start-Process `
  -FilePath 'H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor.exe' `
  -ArgumentList @(
    'H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject',
    '-game', '-dx12', '-windowed', '-ResX=1280', '-ResY=720',
    '-log', '-AttachRenderDoc', '-Log=RenderDocLab.log'
  ) `
  -WindowStyle Normal `
  -PassThru
```

打开 UE 控制台，执行：

```text
renderdoc.CaptureFrame
```

`Alt+F12` 只保证在 Editor/PIE 窗口生效，独立 `-game` 窗口使用控制台命令。捕获后在 Event Browser 中：

1. 展开 Base Pass / BasePassParallel 相关事件。
2. 通过 Cube 的 Index Count、Vertex/Index Buffer 和画面输出定位目标 Indexed Draw。
3. 记录 Event ID、Draw 参数、Graphics Pipeline、Vertex/Pixel Shader。
4. 检查资源绑定中没有业务 Texture/SRV 采样；引擎全局资源不等同于材质贴图。
5. 查看 GBuffer A/B/C、Scene Depth 和最终 Scene Color，记录该 Draw 的像素覆盖。

RenderDoc 记录模板：

| 字段 | 记录内容 |
|---|---|
| Capture 文件 | `Saved\Captures\RenderDoc\StaticBox_20260824_174513.rdc`，39,806,697 bytes |
| Base Pass Event | `BasePass` EID `797–872`；`BasePassParallel` EID `800–857` |
| Draw Marker | `ParallelDraw (Index: 0, Num: 1)` → `/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial Cube (1 instances)` |
| API Draw | EID `841`，Action `107`，`DrawIndexedInstanced(144, 1)` |
| Pipeline | Pipeline State `1084`，Root Signature `795`，Triangle List |
| Vertex 输入 | Index Buffer `ResourceId::342`，index stride 2；Position stream stride 12；Instance stream `ResourceId::702` |
| VS 资源 | Instance Culling、`GPUScene.InstanceSceneData`、`GPUScene.PrimitiveData` 和几何 Buffer |
| PS 资源 | GPU Scene 数据；三个 1×1 全局 Dummy/Default Texture 与一个 Clamp/Point Sampler；没有业务材质贴图 |
| GBuffer | SceneColor、GBuffer A/B/C/D 和 SceneDepthZ（D32S8） |

## PIX 2603.25

PIX 的普通 `attach <PID>` 只能连接由 PIX 启动并已安装 GPU Capture Hook 的进程。为了让 Demo 与分析 UI 解耦，同时避免捕获启动帧，本工程使用独立 Game Target、离线 Cook 包和程序化稳定帧捕获。

### 独立 Game Target 与部署包

工程最初使用 `test` 作为项目和 Runtime Module 名称。当前工程已统一改名为 `RenderPipelineLab`，Game Target、Editor Target、`.uproject` 与 Runtime Module 使用同一名称。

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  RenderPipelineLab Win64 Development `
  '-Project=H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -WaitMutex -NoHotReloadFromIDE
```

源码引擎首次打包前还需要生成 `UnrealPak.exe`：

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\Build.bat' `
  UnrealPak Win64 Development -WaitMutex
```

UE 5.8 默认开启 Zen Store。本机 Stage 时 Zen oplog 无法在 UnrealPak 退出后保持连接，因此项目在 `DefaultGame.ini` 覆盖 `bUseZenStore=False`，保留 Pak 和 IoStore，使用离线 Loose Cook 结果打包：

```powershell
& 'H:\Unreal\UnrealEngine\Engine\Build\BatchFiles\RunUAT.bat' BuildCookRun `
  '-project=H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject' `
  -noP4 -platform=Win64 -clientconfig=Development `
  -target=RenderPipelineLab -skipbuild -cook `
  '-map=/Engine/Maps/Entry' -stage -pak -archive `
  '-archivedirectory=H:\Unreal\Workspace\RenderPipelineLab\Saved\StagedPIX' `
  -utf8output
```

部署程序：

```text
H:\Unreal\Workspace\RenderPipelineLab\Saved\StagedPIX\Windows\RenderPipelineLab\Binaries\Win64\RenderPipelineLab.exe
```

直接启动该程序时，`DefaultGameUserSettings.ini` 将窗口模式设为 1280×1080，不需要额外传入 `-windowed`、`-ResX` 或 `-ResY`。分析工具需要固定其他捕获尺寸时，仍可通过命令行覆盖默认值；本节下方的实际 PIX 证据使用 1280×720。

修改 `DefaultGameUserSettings.ini` 后需要至少执行一次完整 `-cook`。只执行 `-skipcook` 可能继续把旧的 `Saved/Cooked/.../GameUserSettings.ini` 打入 Pak，使旧分辨率覆盖项目默认值。当前部署包已确认不包含该旧运行时配置。

### 稳定帧程序化捕获

命令行存在 `-pixautocapture` 时，`ARenderPipelineProbeActor` 在 `Stage=Ready` 后等待 5 秒，再执行 `pix.GpuCaptureFrame`。普通运行不启用该逻辑。

```powershell
$Pix = 'C:\Program Files\Microsoft PIX\2603.25\pixtool.exe'
$Exe = 'H:\Unreal\Workspace\RenderPipelineLab\Saved\StagedPIX\Windows\RenderPipelineLab\Binaries\Win64\RenderPipelineLab.exe'
$Capture = 'H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\PIX\StaticBox_20260824.wpix'
$PixArgs = '--output=verbose launch "' + $Exe + `
  '" --working-directory="H:\Unreal\Workspace\RenderPipelineLab\Saved\StagedPIX\Windows"' + `
  ' --command-line="-dx12 -windowed -ResX=1280 -ResY=720 -pixautocapture -log -Log=PixCaptureLab.log"' + `
  ' programmatic-capture save-capture "' + $Capture + '"'

Start-Process -FilePath $Pix -ArgumentList $PixArgs `
  -NoNewWindow -Wait -PassThru
```

导出事件与最终颜色资源：

```powershell
& $Pix open-capture $Capture `
  save-event-list 'H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\PIX\StaticBox_20260824.csv'

& $Pix open-capture $Capture `
  save-event-list 'H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\PIX\StaticBox_20260824_D3D.csv' `
  '--counter-groups=D3D*'

& $Pix open-capture $Capture `
  save-resource 'H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\PIX\StaticBox_20260824_FinalColor.png'
```

### 实际捕获结果

| 字段 | 结果 |
|---|---|
| Capture 文件 | `Saved\Captures\PIX\StaticBox_20260824.wpix`，19,642,290 bytes |
| 捕获触发 | `Stage=Ready` 后 5 秒；日志包含 `Stage=PixCaptureRequested` 和 `PixWinPlugin: Capturing a frame in PIX` |
| API / GPU | D3D12，NVIDIA GeForce RTX 4080 SUPER |
| 事件规模 | 2,781 行事件；捕获包含两组稳定帧事件 |
| Base Pass Marker | `BasePass` → `BasePassParallel` → `/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial Cube (1 instances)` |
| Cube Draw | Global ID `307`、`909`，`DrawIndexedInstanced` |
| D3D Pipeline Statistics | IA Vertices `144`，IA Primitives `48`，VS Invocations `57`，PS Invocations `133761`，Samples Rendered `133761` |
| Deferred Lighting | `RenderDeferredLighting`；`RenderLight Light::StandardDeferred: RenderPipelineProbeActor...` |
| Final Color | `Saved\Captures\PIX\StaticBox_20260824_FinalColor.png`，1280×720，确认白色 Cube 可见 |
| 运行时开关 | `r.ForwardShading=0`、`r.Nanite.ProjectEnabled=0`、`r.DynamicGlobalIlluminationMethod=0`、`r.ReflectionMethod=0`、`r.RayTracing=0`、`r.Substrate=0`、`r.Shadow.Virtual.Enable=0` |

`save-screenshot` 依赖 capture-time screenshot；本次程序化捕获未嵌入该图像，因此使用 `save-resource` 导出最终绑定的颜色资源。`.wpix` 回放、事件列表和 D3D Pipeline Statistics 均正常。

## Nsight Graphics 2026.3.1

Nsight Graphics 是进程内工具，不能附加到一个完全未经过 Nsight 启动或注入的普通进程。操作上保持“Demo 运行后 UI 再连接”，但目标必须从启动阶段处于 Nsight 捕获环境。

程序：

```text
H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor.exe
```

参数：

```text
H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject -game -dx12 -windowed -ResX=1280 -ResY=720 -log -Log=NsightRenderPipelineLab.log
```

工作目录：

```text
H:\Unreal\Workspace\RenderPipelineLab
```

### UI 操作步骤

1. 关闭 RenderDoc 注入过的 Demo。
2. 打开 Nsight Graphics，选择 Graphics Capture；需要 GPU 时间线时另起一次 GPU Trace Activity。
3. 配置上述程序、参数和工作目录，由 Nsight 创建捕获环境并启动目标。
4. Demo 到达 `Stage=Ready` 后，在 Nsight UI 连接目标进程并捕获稳定帧。
5. 在 API Inspector / Event View 中定位对应 Base Pass Indexed Draw。
6. 记录 Shader、资源绑定、GPU 区间、Graphics Queue 和同步关系。

Nsight 记录模板：

| 字段 | 记录内容 |
|---|---|
| Capture 文件 | `Saved\Captures\Nsight\` 下的实际文件名 |
| Base Pass Event | 捕获后填写事件名和 API 调用 |
| Shader / Pipeline | 捕获后填写实际标识 |
| GPU 区间 | 捕获后填写时间范围；只作为当前 RTX 4080 SUPER 观察 |
| Queue / Sync | 捕获后填写 Graphics Queue、Fence/Wait 关系 |

### 无 UI 自动捕获

Windows 防火墙权限弹窗或 `ngfx.exe` Qt 前端异常不影响 `ngfx-capture.exe`。以下命令由 Nsight 在目标进程启动时注入，15 秒后自动捕获稳定帧，不需要点击 F11 或批准网络访问：

```powershell
& 'C:\Program Files\NVIDIA Corporation\Nsight Graphics 2026.3.1\host\windows-desktop-nomad-x64\ngfx-capture.exe' `
  --exe='H:\Unreal\UnrealEngine\Engine\Binaries\Win64\UnrealEditor.exe' `
  --working-dir='H:\Unreal\Workspace\RenderPipelineLab' `
  --output-file='H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\Nsight\StaticBox_Timer_20260824.nsight-gfx' `
  --capture-countdown-timer=15000 `
  --frame-count=1 `
  --terminate-after-capture `
  --disable-hang-detection `
  --no-block-on-interfering-application `
  --diagnostic-mode `
  --args='H:\Unreal\Workspace\RenderPipelineLab\RenderPipelineLab.uproject -game -dx12 -windowed -ResX=1280 -ResY=720 -log -Log=NsightTimerLab.log'
```

实际捕获：

| 字段 | 结果 |
|---|---|
| Capture 文件 | `Saved\Captures\Nsight\StaticBox_Timer_20260824.nsight-gfx.ngfx-capture` |
| 捕获帧 | Frame `3266`，1280×720 |
| API / GPU | D3D12，NVIDIA GeForce RTX 4080 SUPER，Driver 610.88 |
| 内容规模 | 715 events，588 resources，约 66 MiB |
| 函数流 | 包含多次 `ID3D12CommandQueue_ExecuteCommandLists` 与 `ID3D12GraphicsCommandList_DrawIndexedInstanced`，最终 `IDXGISwapChain_Present` |
| 有效性 | `has_unsupported_operation=false` |
| 预览图 | `Saved\Captures\Nsight\StaticBox_Timer_20260824.png`，确认目标 Cube 在捕获帧中 |
| 限制 | 捕获报告资源重叠和 RecreateAtGpuva 不可用提示；本机回放可用，不将该文件视为跨机器可移植基线 |

## 实际源码断点证据

### Primitive 创建

触发方式：Visual Studio Attach 到独立 Demo，按 `3` 后启用断点，再按 `4`。

线程：`GameThread`。

```text
ARenderPipelineProbeActor::CreateProbeMesh
→ UActorComponent::RegisterComponentWithWorld
→ UStaticMeshComponent::CreateRenderState_Concurrent
→ UPrimitiveComponent::CreateRenderState_Concurrent
→ FScene::AddPrimitive
→ FScene::BatchAddPrimitivesInternal<UPrimitiveComponent>
→ FActorPrimitiveComponentInterface::CreateSceneProxy
→ UStaticMeshComponent::CreateSceneProxy
```

### Cached Base Pass Draw Command 构建

线程：`Foreground Worker #1`。

```text
FScene::Update 的 RDG Setup Task
→ FPrimitiveSceneInfo::CacheMeshDrawCommands
→ ParallelFor
→ FPrimitiveSceneInfo::CacheMeshDrawCommands lambda
→ FBasePassMeshProcessor::AddMeshBatch
```

`FMeshPassProcessor::BuildMeshDrawCommands` 与 `SetDrawParametersAndFinalize` 在 Development Editor 下被优化/内联，没有独立可绑定地址；以 `AddMeshBatch` 调用栈和 RenderDoc 的 PSO/Draw 结果共同取证。

### Visible Draw 提交

线程：`Foreground Worker #1`。

```text
FDrawVisibleMeshCommandsAnyThreadTask::DoTask
→ FInstanceCullingContext::SubmitDrawCommands
→ FMeshDrawCommand::SubmitDrawBegin
```

### RHI Submit

线程：`RenderThread 0`。

```text
FSceneRenderProcessor / Render Command Pipe
→ FRDGBuilder::Execute
→ FRHICommandListImmediate::QueueAsyncCommandListSubmit
→ FRHICommandListExecutor::Submit
```

### D3D12 Queue Submit

线程：`RHISubmissionThread`。

```text
FD3D12Thread::Run
→ FD3D12DynamicRHI::ProcessSubmissionQueue
→ FD3D12DynamicRHI::FlushBatchedPayloads
→ FD3D12Queue::ExecuteCommandLists
```

## 证据判定

| 结论类型 | 证据 |
|---|---|
| 版本中存在的实现 | UE 5.8.1 对应源码、CVar 和平台条件 |
| 当前 Demo 实际走的 CPU 路径 | Visual Studio 命中栈、线程名和实验动作日志 |
| 当前帧实际执行的 GPU 工作 | RenderDoc/Nsight 的事件、资源和 Pipeline |
| 当前硬件成本 | Nsight GPU Trace 或硬件计数器；本实验不外推到其他 GPU |

## 临时文件边界

- RenderDoc：`H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\RenderDoc`
- Nsight：`H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\Nsight`
- PIX：`H:\Unreal\Workspace\RenderPipelineLab\Saved\Captures\PIX`
- 抓帧和工具缓存不复制到 `D:\IvanOneDriveCloud\ivan-ai-driven`
- RenderDoc、Nsight 与 PIX 不在同一个 Demo 进程中共同 Hook
