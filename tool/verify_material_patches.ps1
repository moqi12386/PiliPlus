# Replays the material_ui patch pipeline from a pristine package, in the same
# order patch.ps1 uses. Run this after editing anything in lib/scripts/material/.
#
#   pwsh -File tool/verify_material_patches.ps1
#
# Exits non-zero if any patch fails to apply.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$lock = Join-Path $repoRoot 'pubspec.lock'

# material_ui version actually resolved by pub, e.g. "1.11.0"
$lockText = Get-Content $lock -Raw
$match = [regex]::Match(
    $lockText,
    'name:\s*"?material_ui"?[\s\S]{0,200}?version:\s*"([^"]+)"'
)
if (-not $match.Success) {
    throw 'cannot find material_ui version in pubspec.lock'
}
$version = $match.Groups[1].Value
Write-Host "material_ui $version"

$work = Join-Path ([System.IO.Path]::GetTempPath()) "mui_patch_check_$PID"
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    Push-Location $work
    curl.exe -sSL --max-time 300 -o mui.tar.gz "https://pub.dev/api/archives/material_ui-$version.tar.gz"
    tar.exe -xzf mui.tar.gz
    Remove-Item mui.tar.gz
    git init -q
    git config user.name 'patch-check'
    git config user.email 'patch-check@local'
    git add -A
    git commit -q -m pristine

    # Keep this order in sync with $patches_material in lib/scripts/patch.ps1.
    $patches = @(
        'modal_barrier_material.patch',
        'navigation_drawer.patch',
        'popup_menu.patch',
        'fab.patch',
        'text_field.patch',
        'scaffold.patch',
        'refresh_indicator.patch',
        'tabs.patch',
        'glass_popup_menu.patch',
        'bottom_sheet_android.patch'
    )

    $failed = @()
    foreach ($patch in $patches) {
        $path = Join-Path $repoRoot "lib/scripts/material/$patch"
        git apply $path 2>$null
        if ($LASTEXITCODE -ne 0) {
            $failed += $patch
            Write-Host "FAILED $patch" -ForegroundColor Red
        } else {
            Write-Host "applied $patch"
        }
    }

    if ($failed.Count -gt 0) {
        throw "$($failed.Count) patch(es) failed: $($failed -join ', ')"
    }
    Write-Host "all $($patches.Count) material patches applied cleanly"
} finally {
    Pop-Location
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
