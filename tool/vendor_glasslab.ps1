# Vendors the parts of Kyant0/AndroidLiquidGlass this lab needs into a plain
# Android/Kotlin module, because the upstream sources are Compose Multiplatform
# (expect/actual) and this project has no multiplatform source sets.
#
# Two mechanical transformations:
#   1. the four `expect` declarations are dropped and the Android `actual`s are
#      kept, with the `actual` keyword removed;
#   2. `@Language("AGSL")` is stripped so we do not depend on org.jetbrains:annotations.
#
# Everything else is copied byte for byte, package names included, so the code can
# be diffed against upstream. Re-run this script instead of hand-editing the
# copies:  pwsh -File tool/vendor_glasslab.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$upstream = Join-Path $repoRoot '_upstream/AndroidLiquidGlass'
$target = Join-Path $repoRoot 'glasslab/app/src/main/kotlin'

if (-not (Test-Path $upstream)) {
    throw "upstream checkout not found at $upstream (expected backdrop/ and app/ from Kyant0/AndroidLiquidGlass)"
}

$backdropCommon = Join-Path $upstream 'backdrop/src/commonMain/kotlin'
$backdropAndroid = Join-Path $upstream 'backdrop/src/androidMain/kotlin'
$catalog = Join-Path $upstream 'app/src/commonMain/kotlin'

$expectOnly = @(
    'com/kyant/backdrop/Platform.kt',
    'com/kyant/backdrop/internal/Paint.kt',
    'com/kyant/backdrop/internal/RenderEffect.kt'
)

function Copy-Tree {
    param([string]$From, [string]$To, [string[]]$Skip = @(), [switch]$StripActual)
    Get-ChildItem $From -Recurse -File -Filter *.kt | ForEach-Object {
        $rel = $_.FullName.Substring($From.Length + 1) -replace '\\', '/'
        if ($Skip -contains $rel) { return }
        $dest = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        $text = Get-Content $_.FullName -Raw
        if ($StripActual) {
            $text = $text -replace '\bactual\s+', ''
            $text = $text -replace '\s*@Language\("AGSL"\)', ''
            $text = $text -replace "import org\.intellij\.lang\.annotations\.Language\r?\n", ''
        }
        # RuntimeShader.kt keeps only the interface; its expect functions are
        # replaced by the Android implementations.
        if ($rel -eq 'com/kyant/backdrop/RuntimeShader.kt') {
            $text = $text -replace 'expect fun RuntimeShader\(@Language\("AGSL"\) shaderString: String\): RuntimeShader\r?\n', ''
            $text = $text -replace 'expect fun RuntimeShader\.asComposeShader\(\): Shader\r?\n', ''
            $text = $text -replace "import org\.intellij\.lang\.annotations\.Language\r?\n", ''
        }
        [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Remove-Item (Join-Path $target 'com') -Recurse -Force -ErrorAction SilentlyContinue

Copy-Tree -From $backdropCommon -To $target -Skip $expectOnly
Copy-Tree -From $backdropAndroid -To $target -StripActual

# catalog components actually used by the lab screen
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
    [System.IO.File]::WriteAllText($dest, (Get-Content $src -Raw), (New-Object System.Text.UTF8Encoding($false)))
}

$count = (Get-ChildItem (Join-Path $target 'com') -Recurse -File -Filter *.kt).Count
Write-Host "vendored $count Kotlin files into glasslab/app/src/main/kotlin"
