// A liquid glass surface for Flutter, ported from Kyant0/AndroidLiquidGlass.
//
// Layout contract: the surface is sized by [child] and the backdrop layer sits
// behind it in a Stack, so the layer always receives tight constraints and can
// compute its own SDF exactly. Nest it anywhere the child has a definite size.
//
// Rendering modes, in order of preference:
//   1. refraction 閳?backdrop is blurred and lensed by a fragment shader
//                   (requires Impeller + `ImageFilter.shader`)
//   2. frosted    閳?backdrop is blurred, tint + rim on top
//   3. plain      閳?solid surface colour, used when glass is disabled or the
//                   engine cannot capture the backdrop at all

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:PiliPlus/common/widgets/glass/glass_config.dart';
import 'package:PiliPlus/common/widgets/glass/glass_shaders.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';

class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    required this.child,
    super.key,
    this.style = GlassStyle.regular,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.enabled,
    this.fallbackColor,
  });

  /// Sizes the surface and paints on top of the glass layers.
  final Widget child;

  final GlassStyle style;

  final BorderRadius borderRadius;

  final EdgeInsetsGeometry? padding;

  /// Overrides the global [GlassConfig.enabled] switch for this surface.
  final bool? enabled;

  /// Colour used when glass is disabled. Defaults to the theme surface colour.
  final Color? fallbackColor;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  ui.FragmentShader? _refraction;
  ui.FragmentShader? _highlight;

  void _ensureShaders() {
    if (GlassCapabilities.supportsShaderFilter) {
      _refraction ??= GlassShaders.newRefractionShader();
    }
    _highlight ??= GlassShaders.newHighlightShader();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled ?? GlassConfig.enabled;
    if (!enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.fallbackColor ?? Theme.of(context).colorScheme.surface,
          borderRadius: widget.borderRadius,
        ),
        child: widget.padding == null
            ? widget.child
            : Padding(padding: widget.padding!, child: widget.child),
      );
    }

    _ensureShaders();
    final style = GlassConfig.resolve(widget.style);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: _GlassBackdrop(
            borderRadius: widget.borderRadius,
            style: style,
            tint: style.tint ?? GlassConfig.tint(context),
            refraction: _refraction,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GlassRimPainter(
                shader: _highlight,
                borderRadius: widget.borderRadius,
                style: style,
              ),
            ),
          ),
        ),
        if (widget.padding == null)
          widget.child
        else
          Padding(padding: widget.padding!, child: widget.child),
      ],
    );
  }
}

/// Blurred + refracted backdrop with the surface tint on top of it.
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop({
    required this.borderRadius,
    required this.style,
    required this.tint,
    required this.refraction,
  });

  final BorderRadius borderRadius;
  final GlassStyle style;
  final Color tint;
  final ui.FragmentShader? refraction;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final canRefract =
        refraction != null &&
        style.refractionHeight > 0 &&
        GlassCapabilities.supportsShaderFilter;

    return ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          ui.ImageFilter? filter;
          if (size.isFinite &&
              size.width > 0 &&
              size.height > 0 &&
              GlassConfig.captureBackdrop) {
            if (canRefract) {
              _applyRefractionUniforms(refraction!, size, dpr);
              final shaderFilter = ui.ImageFilter.shader(refraction!);
              filter = style.blurSigma > 0
                  ? ui.ImageFilter.compose(
                      outer: shaderFilter,
                      inner: ui.ImageFilter.blur(
                        sigmaX: style.blurSigma,
                        sigmaY: style.blurSigma,
                        tileMode: TileMode.clamp,
                      ),
                    )
                  : shaderFilter;
            } else if (style.blurSigma > 0) {
              filter = ui.ImageFilter.blur(
                sigmaX: style.blurSigma,
                sigmaY: style.blurSigma,
                tileMode: TileMode.clamp,
              );
            }
          }

          final layers = Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: tint),
              if (style.sheenOpacity > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromRGBO(255, 255, 255, style.sheenOpacity),
                        const Color(0x00FFFFFF),
                      ],
                      stops: const [0, 0.65],
                    ),
                  ),
                ),
            ],
          );

          return filter == null
              ? layers
              : BackdropFilter(filter: filter, child: layers);
        },
      ),
    );
  }

  /// Uniform layout: 0-1 are engine-provided (texture size), 2-3 rect size,
  /// 4-7 corner radii, 8 refraction height, 9 amount, 10 depth, 11 dispersion.
  /// All geometry is in physical pixels because the filter input texture is.
  void _applyRefractionUniforms(
    ui.FragmentShader shader,
    Size size,
    double dpr,
  ) {
    final width = size.width * dpr;
    final height = size.height * dpr;
    final maxRadius = math.min(width, height) * 0.5;
    final radii = _cornerRadii(borderRadius, size);

    shader
      ..setFloat(2, width)
      ..setFloat(3, height)
      ..setFloat(4, math.min(radii.topLeft.x * dpr, maxRadius))
      ..setFloat(5, math.min(radii.topRight.x * dpr, maxRadius))
      ..setFloat(6, math.min(radii.bottomRight.x * dpr, maxRadius))
      ..setFloat(7, math.min(radii.bottomLeft.x * dpr, maxRadius))
      ..setFloat(8, style.refractionHeight * dpr)
      ..setFloat(9, -style.refractionAmount * dpr)
      ..setFloat(10, style.depthEffect ? 1 : 0)
      ..setFloat(11, style.dispersion);
  }
}

/// Specular rim + hairline border drawn on top of the glass.
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.shader,
    required this.borderRadius,
    required this.style,
  });

  final ui.FragmentShader? shader;
  final BorderRadius borderRadius;
  final GlassStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final radii = _cornerRadii(borderRadius, size);
    final maxRadius = size.shortestSide * 0.5;

    final s = shader;
    if (s != null) {
      // Paint shaders receive logical coordinates, unlike the backdrop filter.
      s
        ..setFloat(0, math.min(radii.topLeft.x, maxRadius))
        ..setFloat(1, math.min(radii.topRight.x, maxRadius))
        ..setFloat(2, math.min(radii.bottomRight.x, maxRadius))
        ..setFloat(3, math.min(radii.bottomLeft.x, maxRadius))
        ..setFloat(4, style.rimColor.r)
        ..setFloat(5, style.rimColor.g)
        ..setFloat(6, style.rimColor.b)
        ..setFloat(7, style.rimColor.a)
        ..setFloat(8, size.width)
        ..setFloat(9, size.height)
        ..setFloat(10, style.rimAngle * math.pi / 180)
        ..setFloat(11, style.rimFalloff)
        ..setFloat(12, style.ambientRim ? 1 : 0);

      // The original draws the highlight as a stroked outline: only the thin
      // ring inside the shape edge receives the shader.
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(style.rimWidth * 2, 0.5)
        ..shader = s
        ..blendMode = style.ambientRim ? BlendMode.srcOver : BlendMode.plus;
      if (style.rimBlur > 0) {
        rimPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, style.rimBlur);
      }

      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRRect(rrect, rimPaint)
        ..restore();
    }

    if (style.borderColor.a > 0) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = style.borderColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.style != style;
  }
}

BorderRadius _cornerRadii(BorderRadius radius, Size size) {
  final maxRadius = size.shortestSide * 0.5;
  double clamp(Radius r) => math.min(r.x, maxRadius);
  return BorderRadius.only(
    topLeft: Radius.circular(clamp(radius.topLeft)),
    topRight: Radius.circular(clamp(radius.topRight)),
    bottomRight: Radius.circular(clamp(radius.bottomRight)),
    bottomLeft: Radius.circular(clamp(radius.bottomLeft)),
  );
}
