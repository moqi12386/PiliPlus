// User-supplied wallpaper, drawn behind the whole app.
//
// Why this exists: liquid glass only reads as glass when there is something
// behind it to refract. PiliPlus paints every page with an opaque surface, so
// cards, settings rows and app bars had nothing but a flat colour behind them.
// With a wallpaper on, those surfaces get real content to blur, and the effect
// finally shows up outside of the bottom bar and the dialogs.
//
// Enabling a wallpaper makes the page surfaces transparent, which is why it is
// opt-in and why the scrim exists: text keeps its contrast against an arbitrary
// photo through a theme-tinted veil.

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class Wallpaper {
  /// Path of the selected image, or null when the feature is off.
  static String? get path {
    final p = Pref.wallpaperPath;
    if (p == null || p.isEmpty) {
      return null;
    }
    return File(p).existsSync() ? p : null;
  }

  static bool get active => path != null;

  /// Veil painted over the photo so foreground text stays readable. Dark mode
  /// needs a heavier veil than light mode.
  static Color scrimOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0x99000000) : const Color(0x66FFFFFF);
  }
}

/// Paints [child] on top of the selected wallpaper.
class WallpaperLayer extends StatelessWidget {
  const WallpaperLayer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = Wallpaper.path;
    if (path == null) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => ColoredBox(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        ColoredBox(color: Wallpaper.scrimOf(context)),
        child,
      ],
    );
  }
}
