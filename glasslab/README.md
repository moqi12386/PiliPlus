# 玻璃实验室（GlassLab）

一个**独立的小应用**，唯一目的是把 [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)
的**原始界面代码**跑在真机上，用来和 PiliPlus 里的 Flutter 移植版做逐项对比。

它不是 PiliPlus 的一部分，不需要 Flutter，也不影响主应用。

## 里面有什么

- 底部导航栏 = 原项目 `catalog/components/LiquidBottomTabs.kt` + `LiquidBottomTab.kt`
  的**源码逐字搬入**（连同 `DampedDragAnimation`、`InteractiveHighlight`、
  `DragGestureInspector`）
- 底下那层玻璃库 = 原项目 `backdrop` 模块的 **35 个 Kotlin 文件**，同样是源码搬入
- 页面内容（渐变 + 三个圆）用 `Modifier.layerBackdrop(backdrop)` 录进背板，
  所以玻璃折射的是真实像素

## 为什么不是"引入依赖"

原库没有发布到 Maven 的 `backdrop` 坐标（真正发布的只有 `io.github.kyant0:shapes`），
而且它是 Compose Multiplatform 结构（`expect/actual`）。这里用
`tool/vendor_glasslab.ps1` 做两处机械变换后搬入：

1. 去掉 4 个 `expect` 声明，保留 Android 的 `actual` 实现并删掉 `actual` 关键字；
2. 去掉 `@Language("AGSL")` 注解，省掉 `org.jetbrains:annotations` 依赖。

除此之外与上游**逐字一致**，包名也保留为 `com.kyant.backdrop.*`，可以直接和上游源码 diff。
要更新上游代码，重新跑一次那个脚本，不要手改 `glasslab/app/src/main/kotlin/com/kyant`。

## 构建

```bash
gradle -p glasslab assembleDebug
```

CI 里有独立的工作流 `.github/workflows/glasslab.yml`（workflow_dispatch 手动触发）。

## 限制

- 透镜折射依赖 `android.graphics.RuntimeShader`，**API 33+**；低版本原库会退化
- 这个应用只用来"看效果"，没有任何真实功能
