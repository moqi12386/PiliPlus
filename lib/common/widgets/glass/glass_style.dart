// Visual parameters of one liquid glass surface.
//
// Field semantics follow Kyant0/AndroidLiquidGlass' `BackdropEffectScope.lens`
// and `HighlightStyle`:
//   refractionHeight  鈥?width of the lens band inside the shape edge, px
//   refractionAmount  鈥?peak displacement of the backdrop, px
//   depthEffect       鈥?adds a centre-facing bias to the lens gradient
//   dispersion        鈥?chromatic aberration strength, 0 disables it
//   rimColor/angle/falloff 鈥?the specular rim light

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

@immutable
class GlassStyle {
  const GlassStyle({
    this.blurSigma = 14,
    this.refractionHeight = 24,
    this.refractionAmount = 18,
    this.depthEffect = true,
    this.dispersion = 0,
    this.tint,
    this.sheenOpacity = 0.06,
    this.rimColor = const Color(0x8CFFFFFF),
    this.rimWidth = 0.9,
    this.rimBlur = 0.45,
    this.rimAngle = 45,
    this.rimFalloff = 1,
    this.ambientRim = false,
    this.borderColor = const Color(0x1FFFFFFF),
    this.shadows = const <BoxShadow>[],
  });

  /// Gaussian blur applied to the captured backdrop before refraction.
  final double blurSigma;

  /// Height of the lens band, in logical pixels.
  final double refractionHeight;

  /// Peak backdrop displacement, in logical pixels.
  final double refractionAmount;

  /// Biases the lens normal toward the shape centre (rounder looking glass).
  final bool depthEffect;

  /// Chromatic aberration strength. 0 keeps the cheap single-tap path.
  final double dispersion;

  /// Fill painted over the backdrop. `null` picks a brightness-aware default.
  final Color? tint;

  /// Alpha of the diagonal white sheen painted on top of the tint.
  final double sheenOpacity;

  /// Specular rim colour; alpha doubles as the rim intensity.
  final Color rimColor;

  /// Width of the rim stroke, in logical pixels. The stroke is centred on the
  /// shape edge and clipped, so the visible ring is about half of it.
  final double rimWidth;

  /// Blur sigma applied to the rim stroke.
  final double rimBlur;

  /// Light direction for the rim, in degrees.
  final double rimAngle;

  /// Exponent shaping how fast the rim fades toward the shape centre.
  final double rimFalloff;

  /// Uses the ambient (top-light only) rim instead of the directional one.
  final bool ambientRim;

  /// Hairline border drawn on the shape edge.
  final Color borderColor;

  /// Outer shadows. PiliPlus is a zero-shadow UI, so this is empty by default.
  final List<BoxShadow> shadows;

  GlassStyle copyWith({
    double? blurSigma,
    double? refractionHeight,
    double? refractionAmount,
    bool? depthEffect,
    double? dispersion,
    Color? tint,
    double? sheenOpacity,
    Color? rimColor,
    double? rimWidth,
    double? rimBlur,
    double? rimAngle,
    double? rimFalloff,
    bool? ambientRim,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) {
    return GlassStyle(
      blurSigma: blurSigma ?? this.blurSigma,
      refractionHeight: refractionHeight ?? this.refractionHeight,
      refractionAmount: refractionAmount ?? this.refractionAmount,
      depthEffect: depthEffect ?? this.depthEffect,
      dispersion: dispersion ?? this.dispersion,
      tint: tint ?? this.tint,
      sheenOpacity: sheenOpacity ?? this.sheenOpacity,
      rimColor: rimColor ?? this.rimColor,
      rimWidth: rimWidth ?? this.rimWidth,
      rimBlur: rimBlur ?? this.rimBlur,
      rimAngle: rimAngle ?? this.rimAngle,
      rimFalloff: rimFalloff ?? this.rimFalloff,
      ambientRim: ambientRim ?? this.ambientRim,
      borderColor: borderColor ?? this.borderColor,
      shadows: shadows ?? this.shadows,
    );
  }

  /// Balanced default for cards and generic containers.
  static const GlassStyle regular = GlassStyle();

  /// The floating pill navigation bar: thicker glass, stronger lens.
  static const GlassStyle navBar = GlassStyle(
    blurSigma: 20,
    refractionHeight: 30,
    refractionAmount: 26,
    dispersion: 0.35,
    rimColor: Color(0xA6FFFFFF),
  );

  /// App bars and other top surfaces.
  static const GlassStyle appBar = GlassStyle(
    blurSigma: 18,
    refractionHeight: 26,
    refractionAmount: 18,
    tint: Color(0x4DFFFFFF),
  );

  /// Dialogs, popups and bottom sheets.
  static const GlassStyle dialog = GlassStyle(
    blurSigma: 24,
    refractionHeight: 32,
    refractionAmount: 22,
    rimColor: Color(0x99FFFFFF),
  );

  /// Player control overlays: darker glass so white glyphs keep contrast.
  static const GlassStyle player = GlassStyle(
    blurSigma: 16,
    refractionHeight: 22,
    refractionAmount: 14,
    tint: Color(0x40000000),
    sheenOpacity: 0.03,
    rimColor: Color(0x40FFFFFF),
    borderColor: Color(0x14FFFFFF),
  );

  /// Small pills, chips and HUD capsules.
  static const GlassStyle pill = GlassStyle(
    blurSigma: 12,
    refractionHeight: 18,
    refractionAmount: 12,
    rimColor: Color(0x73FFFFFF),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassStyle &&
        other.blurSigma == blurSigma &&
        other.refractionHeight == refractionHeight &&
        other.refractionAmount == refractionAmount &&
        other.depthEffect == depthEffect &&
        other.dispersion == dispersion &&
        other.tint == tint &&
        other.sheenOpacity == sheenOpacity &&
        other.rimColor == rimColor &&
        other.rimWidth == rimWidth &&
        other.rimBlur == rimBlur &&
        other.rimAngle == rimAngle &&
        other.rimFalloff == rimFalloff &&
        other.ambientRim == ambientRim &&
        other.borderColor == borderColor &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
    blurSigma,
    refractionHeight,
    refractionAmount,
    depthEffect,
    dispersion,
    tint,
    sheenOpacity,
    rimColor,
    rimWidth,
    rimBlur,
    rimAngle,
    rimFalloff,
    ambientRim,
    borderColor,
    Object.hashAll(shadows),
  );
}
