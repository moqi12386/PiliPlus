// Liquid bottom navigation — a transcription of Kyant0/AndroidLiquidGlass'
// `catalog/components/LiquidBottomTabs.kt` + `LiquidBottomTab.kt` into Flutter.
//
// The original is Compose, so the code cannot be imported; this file follows its
// structure line by line instead of inventing a bar of its own. What each part
// corresponds to:
//
//   Compose                                    here
//   ─────────────────────────────────────────  ──────────────────────────────
//   Row.drawBackdrop(Capsule, blur 8dp,         LiquidGlass (capsule)
//     lens 24dp) + onDrawSurface(container)
//   Row(alpha 0, colorFilter tint(accent))      _accentRow (ColorFiltered)
//   Box.drawBackdrop(combined, lens 10/14dp,    _pill (second LiquidGlass)
//     chromatic, shadow, innerShadow)
//   DampedDragAnimation(spring 1/1000, press     _value / _press controllers
//     78/56, velocity deformation .75/.25)
//   InteractiveHighlight                        (not ported)
//
// One deliberate difference: the original feeds the pill a *combined* backdrop
// (page + the invisible accent row) so the pill's lens magnifies the glyphs
// themselves. Flutter can only bind the engine's single backdrop to a filter, so
// the accent row is composited on top of the pill and scaled instead — the pill
// still refracts the page, the glyphs are tinted and enlarged, but the
// enlargement is not produced by the lens.

import 'dart:math' as math;

import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:material_ui/material_ui.dart';

import 'package:PiliPlus/common/widgets/glass/glass_config.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';
import 'package:PiliPlus/common/widgets/glass/liquid_glass.dart';

@immutable
class LiquidNavDestination {
  const LiquidNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final Widget icon;
  final Widget? selectedIcon;
}

/// Accent used by the original catalog in light theme.
const Color _kAccentLight = Color(0xFF0088FF);

/// Accent used by the original catalog in dark theme.
const Color _kAccentDark = Color(0xFF0091FF);

class LiquidNavigationBar extends StatefulWidget {
  const LiquidNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.trailing,
    this.height = 64,
    this.style = GlassStyle.navBar,
    this.accentColor,
  });

  final List<LiquidNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Round action pinned to the right end, e.g. the search button.
  final Widget? trailing;

  final double height;
  final GlassStyle style;
  final Color? accentColor;

  @override
  State<LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

class _LiquidNavigationBarState extends State<LiquidNavigationBar>
    with TickerProviderStateMixin {
  static const double _inset = 4;
  static const double _trailingWidth = 44;
  static const double _trailingGap = 6;
  static const double _pressedScale = 78 / 56; // from the original

  // spring(1f, 1000f, visibilityThreshold)
  static const _valueSpec = SpringDescription(
    mass: 1,
    stiffness: 1000,
    damping: 63.24555320336759, // 2 * sqrt(1000) * 1.0
  );
  // spring(1f, 1000f, 0.001f) for the press progress
  static const _pressSpec = _valueSpec;

  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  @override
  void didUpdateWidget(covariant LiquidNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _animateValueTo(widget.selectedIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _press.dispose();
    super.dispose();
  }

  void _animateValueTo(double target) {
    final clamped = target.clamp(
      0.0,
      (widget.destinations.length - 1).toDouble(),
    );
    _value.animateWith(
      SpringSimulation(_valueSpec, _value.value, clamped, _value.velocity),
    );
  }

  void _animatePressTo(double target) {
    _press.animateWith(
      SpringSimulation(_pressSpec, _press.value, target, _press.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent =
        widget.accentColor ?? (isDark ? _kAccentDark : _kAccentLight);
    final container = isDark
        ? const Color(0xFF121212).withValues(alpha: 0.4)
        : const Color(0xFFFAFAFA).withValues(alpha: 0.4);
    final radius = BorderRadius.circular(widget.height / 2);
    final count = widget.destinations.length;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trailingExtent = widget.trailing == null
              ? 0.0
              : _trailingWidth + _trailingGap;
          final tabWidth =
              (constraints.maxWidth - _inset * 2 - trailingExtent) / count;
          final pillHeight = widget.height - _inset * 2;

          Widget tabRow() => Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: _LiquidNavTab(
                    destination: widget.destinations[i],
                    selected: i == widget.selectedIndex,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      widget.onDestinationSelected(i);
                      _animateValueTo(i.toDouble());
                    },
                  ),
                ),
            ],
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _animatePressTo(1),
            onHorizontalDragUpdate: (details) {
              if (tabWidth <= 0) return;
              _value.value = (_value.value + details.delta.dx / tabWidth).clamp(
                0.0,
                (count - 1).toDouble(),
              );
            },
            onHorizontalDragEnd: (_) {
              final target = _value.value.round().clamp(0, count - 1);
              _animateValueTo(target.toDouble());
              _animatePressTo(0);
              if (target != widget.selectedIndex) {
                widget.onDestinationSelected(target);
              }
            },
            onHorizontalDragCancel: () {
              final target = _value.value.round().clamp(0, count - 1);
              _animateValueTo(target.toDouble());
              _animatePressTo(0);
            },
            child: LiquidGlass(
              style: GlassStyle.navBar.copyWith(
                // blur(8dp) + lens(24dp) + containerColor, from the original
                blurSigma: 8,
                refractionHeight: 24,
                refractionAmount: 24,
                dispersion: 0,
                tint: container,
                sheenOpacity: 0,
                rimColor: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                rimWidth: 0.8,
                borderColor: Colors.transparent,
              ),
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(_inset),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_value, _press]),
                  builder: (context, _) {
                    final pillLeft = _value.value * tabWidth;
                    final pillRect = Rect.fromLTWH(
                      pillLeft,
                      0,
                      tabWidth,
                      pillHeight,
                    );
                    // pressProgress -> scale 1..78/56, then the velocity
                    // deformation from the original layer block.
                    final pressScale =
                        1 + (_pressedScale - 1) * _press.value.clamp(0.0, 1.0);
                    final speed =
                        (_value.velocity /
                                math.max(tabWidth * (count - 1), 1.0))
                            .clamp(-1.2, 1.2);
                    final scaleX =
                        pressScale / (1 - (speed * 0.75).clamp(-0.2, 0.2));
                    final scaleY =
                        pressScale * (1 - (speed * 0.25).clamp(-0.2, 0.2));
                    final pillRadius = BorderRadius.circular(pillHeight / 2);

                    return Stack(
                      children: [
                        // The pill: second glass surface, lens + dispersion.
                        Positioned(
                          left: pillLeft,
                          top: 0,
                          width: tabWidth,
                          height: pillHeight,
                          child: IgnorePointer(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..scaleByDouble(scaleX, scaleY, 1, 1),
                              child: LiquidGlass(
                                style: GlassStyle.pill.copyWith(
                                  blurSigma: 0,
                                  refractionHeight: 10 * _press.value,
                                  refractionAmount: 14 * _press.value,
                                  depthEffect: true,
                                  dispersion: _press.value * 0.9,
                                  // Original: drawRect(black|white @ 0.1,
                                  // alpha = 1 - progress), so the pill reads as a
                                  // faint plate at rest and becomes pure lens
                                  // while pressed.
                                  tint: (isDark ? Colors.white : Colors.black)
                                      .withValues(
                                        alpha:
                                            0.1 *
                                            (1 - _press.value.clamp(0.0, 1.0)),
                                      ),
                                  sheenOpacity: 0,
                                  rimColor: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.22 * _press.value),
                                  borderColor: Colors.transparent,
                                ),
                                borderRadius: pillRadius,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                        // Base row, drawn in the container's own colour.
                        Positioned.fill(child: tabRow()),
                        // The accent row, tinted and magnified, revealed only
                        // inside the pill — this is the original's "invisible
                        // tinted copy under the moving lens".
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipPath(
                              clipper: _PillClipper(pillRect, pillRadius),
                              child: Transform(
                                alignment: Alignment(
                                  tabWidth <= 0
                                      ? 0
                                      : (pillRect.center.dx /
                                                    (constraints.maxWidth -
                                                        _inset * 2 -
                                                        trailingExtent)) *
                                                2 -
                                            1,
                                  0,
                                ),
                                transform: Matrix4.identity()
                                  ..scaleByDouble(1.1, 1.1, 1, 1),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    accent,
                                    BlendMode.srcIn,
                                  ),
                                  child: tabRow(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.trailing != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            width: _trailingWidth,
                            height: pillHeight,
                            child: widget.trailing!,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Clips to the pill's rounded rect, in the bar's own coordinates.
class _PillClipper extends CustomClipper<Path> {
  const _PillClipper(this.rect, this.radius);

  final Rect rect;
  final BorderRadius radius;

  @override
  Path getClip(Size size) => Path()..addRRect(radius.toRRect(rect));

  @override
  bool shouldReclip(_PillClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}

class _LiquidNavTab extends StatelessWidget {
  const _LiquidNavTab({
    required this.destination,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final LiquidNavDestination destination;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: color, size: 22),
                child: AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: selected
                      ? (destination.selectedIcon ?? destination.icon)
                      : destination.icon,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round glass action for the right end of the bar (search, when the search
/// bar is configured to live in the bottom navigation).
class LiquidNavAction extends StatelessWidget {
  const LiquidNavAction({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.color,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = LiquidGlass(
      style: GlassStyle.pill.copyWith(
        blurSigma: 8,
        tint: GlassConfig.tint(context),
        rimColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.18),
      ),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                size: 22,
                color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
