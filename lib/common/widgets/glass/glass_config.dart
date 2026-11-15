// Global switch + tuning for the liquid glass UI.
//
// Kept separate from the widgets so that surfaces scattered across the app can
// query one cheap flag instead of threading a parameter through every call site.

import 'package:material_ui/material_ui.dart';

import 'package:PiliPlus/common/widgets/glass/glass_shaders.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';

abstract final class GlassConfig {
  /// User-facing switch (persisted as `liquidGlassEnabled`). When false every
  /// glass surface falls back to a plain translucent surface.
  static bool enabled = true;

  /// Master multiplier applied to every surface's blur radius. Lowering it is
  /// the cheap way to trade fidelity for frame time on weak GPUs.
  static double blurScale = 1.0;

  /// When false, surfaces never capture the backdrop: no blur, no refraction,
  /// just tint + rim. Useful as an emergency performance fallback.
  static bool captureBackdrop = true;

  /// Whether the refractive (lens) term can run on this engine build.
  static bool get canRefract =>
      enabled && captureBackdrop && GlassCapabilities.supportsRefraction;

  /// Whether a frosted (blurred backdrop) surface can run.
  static bool get canBlur => enabled && captureBackdrop;

  /// Reads the effective style for a surface: applies user scale and drops the
  /// lens term when the engine cannot render it.
  static GlassStyle resolve(GlassStyle style) {
    if (!enabled) {
      return style.copyWith(blurSigma: 0, refractionHeight: 0);
    }
    final sigma = style.blurSigma * blurScale;
    if (canRefract) {
      return style.copyWith(blurSigma: sigma);
    }
    return style.copyWith(
      blurSigma: sigma,
      refractionHeight: 0,
      dispersion: 0,
    );
  }

  /// Default translucent fill painted over the captured backdrop. Kept fairly
  /// light so the refracted content stays readable.
  static Color tint(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0x40000000)
        : const Color(0x59FFFFFF);
  }

  @visibleForTesting
  static void resetForTest() {
    enabled = true;
    blurScale = 1.0;
    captureBackdrop = true;
  }
}
