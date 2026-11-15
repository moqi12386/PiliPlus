# Vendors the parts of Kyant0/AndroidLiquidGlass this lab needs into a plain
# Android/Kotlin module, because the upstream sources are Compose Multiplatform
# (expect/actual) and this project has no multiplatform source sets.
#
# Mechanical transformations, all listed here so the copies stay diffable:
#   1. the three `expect`-only files are dropped and the Android `actual`s are
#      kept with the `actual` keyword removed;
#   2. RuntimeShader.kt exists in both source sets and lands on the same path, so
#      the common interface and the Android factories are merged;
#   3. awaitFrame() is reimplemented on Compose's frame clock instead of
#      kotlinx-coroutines-android;
#   4. `@Language("AGSL")` is dropped so org.jetbrains:annotations is not needed;
#   5. `com.kyant.shapes` is not taken as a dependency: Capsule becomes a 50%
#      RoundedCornerShape and the lens code drops the RoundedRectangularShape
#      branch (it already handles CornerBasedShape).
#
# Re-run instead of hand-editing glasslab/app/src/main/kotlin/com/kyant:
#   pwsh -File tool/vendor_glasslab.ps1

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$repoRoot = Split-Path -Parent $PSScriptRoot
$upstream = Join-Path $repoRoot '_upstream/AndroidLiquidGlass'
$target = Join-Path $repoRoot 'glasslab/app/src/main/kotlin'

if (-not (Test-Path $upstream)) {
    throw "upstream sources not found at $upstream - clone Kyant0/AndroidLiquidGlass there first"
}

$backdropCommon = Join-Path $upstream 'backdrop/src/commonMain/kotlin'
$backdropAndroid = Join-Path $upstream 'backdrop/src/androidMain/kotlin'
$catalog = Join-Path $upstream 'app/src/commonMain/kotlin'

$expectOnly = @(
    'com/kyant/backdrop/Platform.kt',
    'com/kyant/backdrop/internal/Paint.kt',
    'com/kyant/backdrop/internal/RenderEffect.kt'
)

function Convert-Text {
    param([string]$Path, [switch]$StripActual)
    $text = Get-Content $Path -Raw
    if ($StripActual) {
        $text = $text -replace '\bactual\s+', ''
        $text = $text -replace '\s*@Language\("AGSL"\)', ''
        $text = $text -replace "import org\.intellij\.lang\.annotations\.Language\r?\n", ''
    }
    return $text
}

function Copy-Tree {
    param([string]$From, [string]$To, [string[]]$Skip = @(), [switch]$StripActual)
    Get-ChildItem $From -Recurse -File -Filter *.kt | ForEach-Object {
        $rel = $_.FullName.Substring($From.Length + 1) -replace '\\', '/'
        if ($Skip -contains $rel) { return }
        $dest = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        $text = Convert-Text -Path $_.FullName -StripActual:$StripActual
        [System.IO.File]::WriteAllText($dest, $text, $utf8)
    }
}

Remove-Item (Join-Path $target 'com') -Recurse -Force -ErrorAction SilentlyContinue

Copy-Tree -From $backdropCommon -To $target -Skip $expectOnly
Copy-Tree -From $backdropAndroid -To $target -StripActual

# 2. merge the interface (common) into the Android implementation (same path)
$rsCommon = Join-Path $backdropCommon 'com/kyant/backdrop/RuntimeShader.kt'
$rsTarget = Join-Path $target 'com/kyant/backdrop/RuntimeShader.kt'
$interface = [regex]::Match(
    (Get-Content $rsCommon -Raw),
    '(?s)interface RuntimeShader \{.*?\n\}'
).Value
if (-not $interface) { throw 'RuntimeShader interface not found upstream' }
$androidBody = [System.IO.File]::ReadAllText($rsTarget, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($rsTarget, $androidBody.TrimEnd() + "`n`n" + $interface + "`n", $utf8)
Write-Host 'merged RuntimeShader.kt (interface + Android factories)'

# 3. awaitFrame() on Compose's frame clock
$awaitFrame = @'
package com.kyant.backdrop.catalog.utils

import androidx.compose.runtime.withFrameNanos

suspend fun awaitFrame() {
    withFrameNanos { }
}
'@
$awaitFramePath = Join-Path $target 'com/kyant/backdrop/catalog/utils/Coroutines.kt'
New-Item -ItemType Directory -Force -Path (Split-Path $awaitFramePath) | Out-Null
[System.IO.File]::WriteAllText($awaitFramePath, $awaitFrame, $utf8)

# catalog pieces the lab screen actually uses
foreach ($rel in @(
    'com/kyant/backdrop/catalog/components/LiquidBottomTabs.kt',
    'com/kyant/backdrop/catalog/components/LiquidBottomTab.kt',
    'com/kyant/backdrop/catalog/utils/DampedDragAnimation.kt',
    'com/kyant/backdrop/catalog/utils/DragGestureInspector.kt',
    'com/kyant/backdrop/catalog/utils/InteractiveHighlight.kt'
)) {
    $src = Join-Path $catalog $rel
    $dest = Join-Path $target $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    [System.IO.File]::WriteAllText($dest, (Get-Content $src -Raw), $utf8)
}

# 5. inline the two shapes instead of depending on io.github.kyant0:shapes
$patched = 0
Get-ChildItem (Join-Path $target 'com') -Recurse -File -Filter *.kt | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $before = $text
    $text = $text -replace "import com\.kyant\.shapes\.Capsule\r?\n", "import androidx.compose.foundation.shape.RoundedCornerShape`n"
    $text = $text -replace '\bCapsule\(\)', 'RoundedCornerShape(percent = 50)'
    if ($_.Name -eq 'Lens.kt') {
        $text = $text -replace "import com\.kyant\.shapes\.RoundedRectangularShape\r?\n", ''
        $text = $text -replace '(?s)\s*is RoundedRectangularShape -> \{.*?\n        \}\r?\n', "`n"
        $text = $text -replace 'Only RoundedRectangularShape or CornerBasedShape', 'Only CornerBasedShape'
    }
    if ($text -ne $before) {
        [System.IO.File]::WriteAllText($_.FullName, $text, $utf8)
        $patched++
    }
}
Write-Host "inlined shapes in $patched file(s)"

$count = (Get-ChildItem (Join-Path $target 'com') -Recurse -File -Filter *.kt).Count
Write-Host "vendored $count Kotlin files into glasslab/app/src/main/kotlin"
