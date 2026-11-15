// Liquid glass shader bootstrap.
//
// The GLSL lives in `assets/glass_shaders/liquid_glass_refraction.frag` and
// `assets/glass_shaders/liquid_glass_highlight.frag`; both are ported from
// Kyant0/AndroidLiquidGlass (Apache-2.0), see the header of each file.
//
// `ui.FragmentProgram.fromAsset` is async, so [load] must be awaited once during
// startup (see `main.dart`). Everything degrades gracefully when loading fails or
// when the engine cannot use shaders as image filters.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

abstract final class GlassShaders {
  static const String refractionAsset =
      'assets/glass_shaders/liquid_glass_refraction.frag';
  static const String highlightAsset =
      'assets/glass_shaders/liquid_glass_highlight.frag';

  static ui.FragmentProgram? _refractionProgram;
  static ui.FragmentProgram? _highlightProgram;
  static bool _loadAttempted = false;

  /// Whether both fragment programs are compiled and ready.
  static bool get isReady =>
      _refractionProgram != null && _highlightProgram != null;

  /// Loads the fragment programs at most once. Never throws: a failure only
  /// disables the refraction/rim shaders and leaves the blur-only path active.
  static Future<void> load() async {
    if (isReady || _loadAttempted) {
      return;
    }
    _loadAttempted = true;
    try {
      _refractionProgram ??= await ui.FragmentProgram.fromAsset(
        refractionAsset,
      );
      _highlightProgram ??= await ui.FragmentProgram.fromAsset(highlightAsset);
    } catch (e, s) {
      _refractionProgram = null;
      _highlightProgram = null;
      if (kDebugMode) {
        debugPrint('LiquidGlass: shader load failed: $e\n$s');
      }
    }
  }

  /// A fresh shader instance for one glass surface.
  ///
  /// Shader objects are mutable (uniforms), so every surface owns its own
  /// instance to avoid one widget overwriting another's uniforms mid-frame.
  static ui.FragmentShader? newRefractionShader() =>
      _refractionProgram?.fragmentShader();

  static ui.FragmentShader? newHighlightShader() =>
      _highlightProgram?.fragmentShader();
}

/// Engine capabilities the glass effect depends on.
abstract final class GlassCapabilities {
  static bool? _shaderFilterSupported;

  /// `ui.ImageFilter.shader` is Impeller-only; on Skia it throws
  /// `UnsupportedError`. `ImageFilter.isShaderFilterSupported` reports it.
  static bool get supportsShaderFilter {
    final cached = _shaderFilterSupported;
    if (cached != null) {
      return cached;
    }
    bool supported;
    try {
      supported = ui.ImageFilter.isShaderFilterSupported;
    } catch (_) {
      supported = false;
    }
    return _shaderFilterSupported = supported;
  }

  /// True when a real lensing (backdrop refraction) effect can be rendered.
  static bool get supportsRefraction =>
      GlassShaders.isReady && supportsShaderFilter;
}
