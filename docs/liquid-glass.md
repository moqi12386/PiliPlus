# 液态玻璃（Liquid Glass）

本 fork 把 [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)
的液态玻璃材质移植到了 PiliPlus 的 Flutter UI 上。

原项目使用 Apache-2.0 许可，着色器数学与参数语义均按原实现 1:1 移植，文件头保留了
来源与许可说明。

---

## 1. 为什么是「移植」而不是「引入依赖」

AndroidLiquidGlass 是一个 **Compose Multiplatform（Kotlin）** 库：

```
backdrop/src/commonMain/kotlin/com/kyant/backdrop/...
  effects/Lens.kt              → 折射（RuntimeShader + RenderEffect）
  highlight/HighlightModifier.kt → 描边高光
  internal/Shaders.kt          → AGSL 着色器源码
```

它的效果依赖三件 Android/Compose 侧的东西：

| 原实现 | 作用 |
| --- | --- |
| `RuntimeShader`（AGSL） | 对背景纹理做 SDF 折射 / 色散 / 高光 |
| `GraphicsLayer.renderEffect` | 把着色器挂到图层上 |
| `GraphicsLayer` 录制 backdrop | 拿到「玻璃背后的内容」 |

而 PiliPlus 是 **Flutter（Dart）** 应用，两者的 UI 运行时不同，Kotlin 库无法直接给
Flutter 部件当材质用。幸运的是 Flutter 里存在一一对应的能力：

| 原实现 | Flutter 对应物 | 说明 |
| --- | --- | --- |
| `RenderEffect` + `RuntimeShader` | `ui.ImageFilter.shader(FragmentShader)` | 唯一的「能读到背景纹理」的 API，**仅 Impeller 支持** |
| AGSL 着色器 | `assets/shaders/*.frag`（FragmentProgram） | 同为 SkSL 系 GLSL 方言，SDF 代码可直接改写 |
| `GraphicsLayer` 录制 | `BackdropFilter` | 引擎自动把背板纹理交给滤镜 |
| `Paint.style = Stroke` 高光 | `Canvas.drawRRect` + `Paint.shader` | 同样是描边环 |

所以移植的产物是：**两个 .frag 着色器 + 一个 Dart 组件库**，不引入任何新依赖。

---

## 2. 目录结构

```
assets/glass_shaders/liquid_glass_refraction.frag   # 折射 + 色散（ImageFilter 用）
assets/glass_shaders/liquid_glass_highlight.frag    # 边缘高光（Paint shader 用）

lib/common/widgets/glass/
  glass_shaders.dart   # FragmentProgram 加载、能力探测
  glass_config.dart    # 全局开关、模糊倍率、取色
  glass_style.dart     # 视觉参数 + 预设（navBar/appBar/dialog/player/pill）
  liquid_glass.dart    # LiquidGlass 组件 + 边缘高光 painter

test/glass/liquid_glass_shader_test.dart      # 离屏渲染验证着色器数学
```

---

## 3. 效果是怎么算出来的

### 3.1 形状：圆角矩形 SDF

与 Kotlin 版一致，用有符号距离场描述圆角矩形，并按四个角分别取半径：

```glsl
float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside  = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}
```

`gradSdRoundedRect` 返回**指向最近边缘的单位方向**（注意不是梯度模长），这是折射位移
方向的来源。

### 3.2 折射（lens）

只有当像素距离边缘小于 `refractionHeight` 时才发生位移，位移量按 `circleMap` 曲线
从 0 增长到 `refractionAmount`：

```glsl
if (-sd >= refractionHeight) { 取原图; }
float d = circleMap(1.0 - (-sd) / refractionHeight) * refractionAmount;
vec2 grad = normalize(gradSdRoundedRect(...) + depthEffect * normalize(centeredCoord));
vec2 refractedCoord = fragCoord + d * grad;
```

- `refractionHeight` 控制「玻璃边缘被压扁的那一圈」有多宽；
- `refractionAmount` 控制压扁的强度（**传负值**，即向玻璃内部取样，视觉上才是凹透镜）；
- `depthEffect` 把位移方向再往中心偏一点，玻璃看起来更「鼓」；
- 玻璃中心区域（`-sd >= refractionHeight`）直接取原图，因此中心不糊、不畸变。

### 3.3 色散（chromatic aberration）

开启后对同一位置做 7 次带色偏的采样，按通道分别加权，模拟边缘彩虹：

```glsl
float dispersionIntensity = dispersion * (centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y);
```

强度与 `x*y` 成正比，所以只有**四个角**附近出现明显色散，直边几乎无色差 —— 和原实现
一致。`dispersion = 0` 时走单次采样，省 6 次纹理取样。

### 3.4 边缘高光（highlight）

原实现不是「把整个面涂白」，而是：

1. 把形状轮廓当作**描边路径**（`PaintingStyle.Stroke`，`strokeWidth = 2 × 宽度`）；
2. 用着色器作为这支画笔的 shader；
3. 让引擎把描边超出形状的部分裁掉，于是可见的只有一圈内侧细环。

着色器给出环上每一点的亮度：`intensity = pow(abs(dot(grad, lightDir)), falloff)`。

- 直边 `|dot| = cos45° ≈ 0.707`，四个角 `|dot| ≈ 1` —— 所以角上最亮、边上略暗；
- `ambient` 模式下额外乘 `step(0, dot)`，只点亮朝向光源的那一半；
- 默认 `rimWidth = 0.9`、`rimBlur = 0.45`，就是一条柔化的发丝高光。

### 3.5 两个必须踩过的坑

**（一）输出必须预乘 alpha。** Flutter 的 `FragmentShader` 把输出当作预乘颜色处理。
最初高光 shader 直接输出 `vec4(rgb, intensity)`，被引擎解释成「不透明的纯白」，整块
玻璃糊成白色。正确写法：

```glsl
float a = intensity * u_colorA;
fragColor = vec4(u_colorR * a, u_colorG * a, u_colorB * a, a);
```

**（二）uniform 不能依赖向量对齐的「巧合」。** 除 `ImageFilter.shader` 强制的首个
`vec2 u_size` 外，全部改成了标量 uniform：

```glsl
uniform vec2 u_size;      // 0-1 引擎写入
uniform sampler2D u_texture;
uniform float u_rectWidth;  // 2
uniform float u_rectHeight; // 3
...
```

因为 `vec4` 在 std140 下需要 16 字节对齐，`vec2` 后面接 `vec4` 会插入空洞，Dart 侧
按声明顺序算出来的 `setFloat` 索引就会整体错位（表现同样是「参数不生效、满屏白」）。
用标量后索引与声明顺序严格一致，且不再受编译器布局策略影响。

---

## 4. 渲染路径与降级

`LiquidGlass` 有三种模式，按能力自动选择：

| 模式 | 触发条件 | 观感 |
| --- | --- | --- |
| 折射 | `ImageFilter.isShaderFilterSupported == true`（Impeller） | 模糊 + 边缘透镜 + 色散 + 高光 |
| 磨砂 | 只有模糊可用 | 模糊背板 + 底色 + 高光 |
| 纯色 | 关闭开关 / 无法捕获背板 | 主题 surface 色 |

**关于 Impeller**：PiliPlus 在 `AndroidManifest.xml` 中显式关闭了 Impeller
（`EnableImpeller=false`），因此**默认走「磨砂」模式**。想要真正的透镜折射，需要把该
开关改为 `true`（见第 7 节）。这不是遗漏，而是刻意保留的降级路径 —— 折射依赖 Impeller，
而 Impeller 在部分机型上仍有兼容性差异。

`GlassConfig` 提供两个运行期旋钮：

```dart
GlassConfig.enabled         // 总开关（持久化键 liquidGlass）
GlassConfig.blurScale       // 全局模糊倍率，低端机可调小
GlassConfig.captureBackdrop // 关掉后完全不采样背板（应急性能模式）
```

---

## 5. 组件 API

```dart
LiquidGlass(
  style: GlassStyle.navBar,                       // 视觉预设
  borderRadius: const BorderRadius.all(Radius.circular(22)),
  child: NavigationBar(...),                      // 决定尺寸，画在玻璃之上
)
```

约束：`LiquidGlass` 由 `child` 决定尺寸，背板层以 `Positioned.fill` 贴在同一个 `Stack`
里，因此**必须放在能给出确定尺寸的父级**中（`SizedBox`、`Positioned.fill`、`Expanded`
等）。这样做的原因是 SDF 需要知道玻璃自身的尺寸，而 `BackdropFilter` 的滤镜在 build
阶段就已经确定。

`GlassStyle` 常用字段：

| 字段 | 含义 |
| --- | --- |
| `blurSigma` | 背板高斯模糊强度 |
| `refractionHeight` / `refractionAmount` | 透镜带宽 / 位移强度 |
| `depthEffect` | 位移方向是否向中心偏移 |
| `dispersion` | 色散强度（0 = 关闭） |
| `tint` / `sheenOpacity` | 底色 / 斜向白色高光 |
| `rimColor` / `rimWidth` / `rimBlur` / `rimAngle` / `rimFalloff` | 边缘高光 |
| `borderColor` | 1px 发丝描边 |

预设：`GlassStyle.regular / navBar / appBar / dialog / player / pill`。

当玻璃关闭时，`LiquidGlass` 退化为 `fallbackColor`（默认主题 surface）填充，调用方
不需要写两套布局。

---

## 6. 已接入的位置

| 界面 | 文件 | 说明 |
| --- | --- | --- |
| 底部导航（M3 栏） | `lib/pages/main/view.dart` | 药丸上方圆角玻璃，导航栏自身背景置透明 |
| 底部导航（悬浮款） | `lib/common/widgets/floating_navigation_bar.dart` | 超椭圆药丸外层换成玻璃，描边交给玻璃高光 |
| 首页搜索条 | `lib/pages/home/view.dart` | 44 高的胶囊玻璃，替换原来的 5% 半透明填充 |
| 确认弹窗 | `lib/common/widgets/dialog/dialog.dart` | `AlertDialog` 背景透明 + 玻璃容器 |
| 播放器控制层 | `lib/plugin/pl_player/widgets/app_bar_ani.dart` | 渐变遮罩下加磨砂背板（`GlassFrost`） |
| 所有弹出菜单 | `lib/scripts/material/glass_popup_menu.patch` + `lib/utils/theme_utils.dart` | 框架层一次性覆盖全部 `showMenu` |
| 设置开关 | `lib/pages/setting/models/style_settings.dart` | 外观设置里的「液态玻璃」开关 |

开关持久化键：`SettingBoxKey.liquidGlass`（默认 `true`），由 `main.dart` 在首帧前读入
`GlassConfig.enabled`，并预编译两个着色器。

### 6.1 弹出菜单为什么走「框架补丁」

`showMenu` 的菜单表面由 `material_ui` 内部的 `_PopupMenu` 绘制，PiliPlus 侧没有任何
包装层可以插入 `BackdropFilter`。但本项目**本来就在给 `material_ui` 打补丁**
（`lib/scripts/material/*.patch`，CI 里 `patch.ps1` 在 `flutter pub get` 之后应用），
所以这里沿用了同一条通道，一次覆盖全部 8 处 `showMenu` 调用点。

难点是「补丁怎么知道你有没有打开玻璃」。两个包之间不能互相 import（会让 PiliPlus 依赖
一个只有打补丁后才存在的 API），所以约定了一个**天然无害**的信号：

```dart
// app 侧（theme_utils.dart）
surfaceTintColor: GlassConfig.enabled ? Colors.transparent : (...)

// 补丁侧（_PopupMenuState.build）
final bool glass = glassSignal != null && glassSignal.a == 0.0;
```

选择 `surfaceTintColor` 而不是 `color` 是关键：如果补丁没被打上，一个全透明的
`surfaceTintColor` 只是「不加染色」，菜单依然正常；而如果拿全透明的 `color` 当信号，
补丁缺失时菜单会直接变透明、文字浮在页面上，属于可见故障。

补丁自己只做三件事：把表面色换成 72% 不透明的主题 surface（保证文字对比度）、
把 elevation 归零、外面套 `ClipPath(ShapeBorderClipper) + BackdropFilter(22)`。
圆角裁剪必须在模糊之外，否则模糊会溢出菜单的圆角。

补丁文件必须**排在 `popup_menu.patch` 之后**应用（它的 hunk 是针对打过该补丁后的
文件生成的），`patch.ps1` 里的数组顺序就是这个约束。改动补丁后可用下面的方式从纯净
包完整复演一遍：

```powershell
# 下载 material_ui 1.11.0 → git init → 按 CI 顺序 git apply 全部 material 补丁
pwsh -File tool/verify_material_patches.ps1   # 见仓库内同名脚本
```

---

## 7. 开启真实折射（可选）

`android/app/src/main/AndroidManifest.xml`：

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="false" />   <!-- 改成 true 即可启用折射 -->
```

改完后 `ImageFilter.isShaderFilterSupported` 为 true，`LiquidGlass` 自动切到折射模式，
无需改任何 UI 代码。若遇到渲染问题，改回 `false` 即退回磨砂模式。

---

## 8. 验证方式

项目里带了一个**离屏**测试，不依赖真机，直接把两个着色器渲染成图片并断言数学正确：

```bash
flutter test test/glass/liquid_glass_shader_test.dart
```

它断言：

1. 玻璃中心像素与背板一致（中心不受折射影响）；
2. 边缘透镜带内的像素确实被位移；
3. 开启色散后颜色通道出现分离；
4. 高光强度在四角最高、直边为 `|cos45°|`；
5. ambient 模式只点亮朝向光源的一侧；
6. 高光是描边环，不会糊满整个面。

> 说明：`flutter test` 走 Skia，而 `ImageFilter.shader` 仅 Impeller 支持，所以测试把
> 着色器当作普通 `Paint.shader` 驱动 —— 被验证的是着色器数学本身，滤镜挂载部分由真机
> 构建验证。

`GLASS_DUMP=1 flutter test ...` 会把渲染结果导出到 `glass_out/*.png` 便于肉眼比对。

---

## 9. 已知限制

- **折射依赖 Impeller**，默认配置下呈现磨砂玻璃（见第 4 节）。
- **每个玻璃面 = 一次背板捕获**。滚动列表里密集铺玻璃会明显吃 GPU，因此只用在
  「浮在内容之上」的固定元件，没有铺到列表卡片上。
- 顶栏（`AppBar`）暂未玻璃化：它需要所在页面开启 `extendBodyBehindAppBar` 才有内容
  可以从背后滚过，属于逐页改动，留给后续迭代。
- 播放器控制层同理（视频纹理上做实时模糊的开销与兼容性需要真机评估），目前保留原有
  渐变遮罩。
- 圆角目前统一按 `BorderRadius` 处理，原实现的超椭圆（superellipse）只在悬浮底栏的
  描边上保留，SDF 仍按普通圆角计算。
