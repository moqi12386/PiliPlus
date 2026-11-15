package com.kyant.glasslab

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import com.kyant.backdrop.catalog.components.LiquidBottomTab
import com.kyant.backdrop.catalog.components.LiquidBottomTabs

/**
 * A throwaway surface for judging the *real* library: the bottom bar below is
 * Kyant0/AndroidLiquidGlass' own `LiquidBottomTabs` source, vendored verbatim, not
 * a Flutter reimplementation of it.
 *
 * Everything drawn into the page box is recorded as the backdrop, so the glass
 * refracts actual pixels instead of an empty layer.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { LabScreen() }
    }
}

private val pageGradient = listOf(
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364),
    Color(0xFF7B2FF7),
)

@Composable
private fun LabScreen() {
    var selected by remember { mutableIntStateOf(0) }
    val backdrop = rememberLayerBackdrop()

    Box(Modifier.fillMaxSize()) {
        // The page. layerBackdrop() records it into the backdrop the glass samples.
        Box(
            Modifier
                .layerBackdrop(backdrop)
                .fillMaxSize()
                .background(Brush.verticalGradient(pageGradient)),
        ) {
            // High-contrast shapes so displacement and dispersion are visible.
            Box(
                Modifier
                    .offset(x = (-40).dp, y = 120.dp)
                    .size(220.dp)
                    .clip(CircleShape)
                    .background(Color(0x66FFFFFF)),
            )
            Box(
                Modifier
                    .offset(x = 200.dp, y = 260.dp)
                    .size(180.dp)
                    .clip(CircleShape)
                    .background(Color(0x88FFC400)),
            )
            Box(
                Modifier
                    .offset(x = 60.dp, y = 430.dp)
                    .size(260.dp)
                    .clip(CircleShape)
                    .background(Color(0x5500E5FF)),
            )

            Column(Modifier.statusBarsPadding().padding(horizontal = 24.dp)) {
                Spacer(Modifier.height(24.dp))
                BasicText(
                    "玻璃实验室",
                    style = TextStyle(Color.White, 30.sp, FontWeight.SemiBold),
                )
                Spacer(Modifier.height(8.dp))
                BasicText(
                    "底栏是原项目 LiquidBottomTabs 的源码，逐字搬过来的。\n" +
                        "按住底栏左右拖动，可以看它的拉伸与折射。",
                    style = TextStyle(Color(0xCCFFFFFF), 14.sp, lineHeight = 20.sp),
                )
                Spacer(Modifier.height(28.dp))
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    LabCard("下面的底栏：真原库", "胶囊 + 透镜药丸 + 染色行，AGSL 渲染")
                    LabCard("折射条件", "API 33+ 才有 RuntimeShader，低版本退化成半透明")
                    LabCard(
                        "对比目的",
                        "和 PiliPlus 里的 Flutter 移植版逐项比：拖动拉伸、按下变透镜、" +
                            "药丸里两个图标同时显形",
                    )
                }
            }
        }

        LiquidBottomTabs(
            selectedTabIndex = { selected },
            onTabSelected = { selected = it },
            backdrop = backdrop,
            tabsCount = 3,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 28.dp)
                .padding(horizontal = 36.dp),
        ) {
            LabTab("首页") { selected = 0 }
            LabTab("动态") { selected = 1 }
            LabTab("我的") { selected = 2 }
        }
    }
}

@Composable
private fun RowScope.LabTab(label: String, onSelect: () -> Unit) {
    LiquidBottomTab(onClick = onSelect) {
        // A plain disc stands in for an icon: the tinted copy inside the pill and
        // the lens magnification are what we are looking at, not the glyph.
        Box(
            Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(Color.White),
        )
        BasicText(label, style = TextStyle(Color.White, 12.sp))
    }
}

@Composable
private fun LabCard(title: String, body: String) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color(0x22FFFFFF))
            .padding(16.dp),
    ) {
        BasicText(title, style = TextStyle(Color.White, 16.sp, FontWeight.Medium))
        Spacer(Modifier.height(4.dp))
        BasicText(body, style = TextStyle(Color(0xBBFFFFFF), 13.sp, lineHeight = 18.sp))
    }
}
