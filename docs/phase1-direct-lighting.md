# Phase1：Standard Deferred Direct Lighting

## 目标

Phase1 用一个普通不透明 Box Shadow Caster、一个普通不透明 Plane Shadow Receiver 和一个 Movable Spot Light，验证 UE5.8.1 的以下链路：

```text
Plane Legacy GBuffer
+ Spot Light Work
+ Local Projected Shadow Visibility
→ Legacy Default Lit
→ Additive Scene Color
```

事实源：`060-Standard Deferred Box 与 Plane：从 GBuffer 与 Shadow Mask 到 Scene Color.md`。

## 固定场景

| 对象 | 固定值 |
|---|---|
| Plane | Location `(0,0,0)`；Scale `(10,10,1)`；Static；Cast Shadow Off |
| Box | Location `(0,0,50)`；Scale `(1,1,1)`；Static；Cast Shadow On |
| Spot Light | Location `(-300,0,400)`；Movable；5000 lm；Radius 1500；Cone 20°/35° |
| Receiver Target | World `(100,0,1)` |
| Camera | Location `(0,-900,500)`；Look At `(60,0,30)`；FOV 60° |

Spot Light 使用默认 Lighting Channel。IES、Light Function、Contact Shadow、Source Radius、Soft Source Radius 和 Source Length 均关闭或为 0。Directional Light、Sky Light、Nanite、Substrate、MegaLights、Ray Tracing、Lumen、Distance Field 和 Static Lighting 不参与本 Phase。

## 运行

```powershell
./Tools/RunRenderPipelinePhase.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode On `
  -LogName Phase1ShadowOn.log

./Tools/RunRenderPipelinePhase.ps1 `
  -ProjectRoot $PWD `
  -Phase Phase1 `
  -ShadowMode Off `
  -LogName Phase1ShadowOff.log
```

## 已验证事实

### Automation Test

- Phase1 必需组件均存在；
- Box / Plane 的 Cast Shadow 与 Mobility 符合合同；
- Spot Light 的形状、Lighting Channel、IES、Light Function 和 MegaLights 标记符合合同；
- ShadowMode 缺省为 On，On / Off 可解析，非法值被拒绝。

### D3D12 运行

Shadow On 与 Shadow Off 均达到：

```text
Phase=Phase1 Stage=Ready
Viewport=1280x1080
TargetWorldPosition=V(X=100.00, Z=1.00)
TargetScreenPosition=(576,579)
FeatureLevel=SM6(4)
```

当前冻结场景的 Receiver Target 为 `V(X=100.00, Z=1.00)`。Shadow On/Off 两轮均得到目标像素 `(576,579)`，运行验证器已通过。`sg.ResolutionQuality=0` 在 UE5.8.1 中表示使用项目默认 Screen Percentage，按实际快照记录，不解释为 Low quality。

本地 HighResShot 已确认 Camera 使用侧视构图，Box 与 Plane 上的投影阴影在屏幕空间分离；目标像素 `(576,579)` 位于可见 Plane 阴影区域，不在 Box 轮廓内。截图位于 `Saved/Screenshots`，属于本地验证件，不提交 Git。

## GPU Capture 证据

Shadow On / Off 均已完成 PIX Capture。Capture 与导出件保留在 `Saved/Captures/PIX`，不提交 Git。

| 观察项 | Shadow On | Shadow Off |
|---|---|---|
| Direct Lighting 分流 | `UnbatchedLights` | `BatchedLights` |
| Shadow Depth | `ShadowDepths → Atlas0 2048x2048 → ShadowDepthPass` | 不存在对应事件 |
| Shadow Projection | `ShadowProjectionOnOpaque → Shadows → Entry.Phase1DirectLightingActor_* → ShadowProjection WholeScene` | 不存在对应事件 |
| Deferred Light | `RenderLight Light::StandardDeferred: Phase1DirectLightingActor_*` | 同名 `RenderLight` 仍存在 |
| 最终画面 | Plane 上存在 Box 投影阴影 | Box 保留，Plane 上投影阴影消失 |

`ShadowProjection WholeScene` 的实际 Draw 已在 PIX Pipeline 中核对：

```text
Depth: SceneDepthZ
RTV0: ShadowMaskTexture
Vertex Shader: res#64
Pixel Shader: res#6
```

这证明固定 Demo 的 Shadow On 帧命中了 Classic Shadow Depth、屏幕空间 Shadow Projection 和 Standard Deferred Light 消费链；Shadow Off 帧跳过对应 Shadow Depth / Projection，并进入 Batched Light 路径。

当前 Capture 没有提供可直接还原为 UE 类型名与宏组合的 shader permutation 符号；目标像素的线性 Visibility、GBuffer 中间值与 Scene Color 数值也尚未逐项导出。这些项继续保留为后续像素级审校工作，不用源码候选替代运行时结果。

## 断点入口

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

C++ 断点证明 CPU 分支；GPU Capture 证明 Pass、Shader 和资源链。
