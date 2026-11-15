// Size-agnostic frosted glass.
//
// [LiquidGlass] needs to know its own size to build the rounded-rect SDF, so it
// requires bounded constraints. Some surfaces (the player's control overlays,
// for instance) are laid out with an unbounded main axis; for those, a plain
// backdrop blur is enough and needs no geometry at all.

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:PiliPlus/common/widgets/glass/glass_config.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';

class GlassFrost extends StatelessWidget {
  const GlassFrost({
    required this.child,
    super.key,
    this.style = GlassStyle.player,
    this.borderRadius = BorderRadius.zero,
    this.enabled,
  });

  final Widget child;

  final GlassStyle style;

  final BorderRadius borderRadius;

  /// Overrides the global [GlassConfig.enabled] switch for this surface.
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? GlassConfig.enabled;
    if (!on || !GlassConfig.captureBackdrop) {
      return child;
    }
    final resolved = GlassConfig.resolve(style);
    if (resolved.blurSigma <= 0) {
      return child;
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: resolved.blurSigma,
          sigmaY: resolved.blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: resolved.tint),
          child: child,
        ),
      ),
    );
  }
}
