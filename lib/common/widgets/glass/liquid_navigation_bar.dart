// Liquid bottom navigation, modelled on the bottom tabs of
// Kyant0/AndroidLiquidGlass (`catalog/components/LiquidBottomTabs.kt`).
//
// What was ported and what was not:
//
//   ported   – the capsule container: one glass surface that blurs the page
//              behind it, tinted white/black at ~40% and rim-lit;
//   ported   – the selection pill: a second, smaller glass lens that travels
//              between tabs with a spring, and squashes along its travel
//              direction with the spring's velocity (the "liquid" part);
//   ported   – accent-tinted selected icon, slightly enlarged inside the pill;
//   dropped  – the original samples a *combined* backdrop (page + an invisible
//              accent-coloured copy of the tab row) so the pill magnifies the
//              glyphs beneath it. Flutter can only bind one backdrop to a
//              filter, so the accent colour is applied to the tab itself
//              instead. The glyph is tinted, not magnified through the lens.
//
// The bar is a layout component: with glass disabled, `LiquidGlass` falls back
// to a plain surface and the same geometry is kept.

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

  /// An extra round action pinned to the right end of the capsule, e.g. the
  /// search button when the search bar is moved down here.
  final Widget? trailing;

  final double height;
  final GlassStyle style;
  final Color? accentColor;

  @override
  State<LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

class _LiquidNavigationBarState extends State<LiquidNavigationBar>
    with SingleTickerProviderStateMixin {
  // Slightly under-damped so the pill overshoots a touch, like the original.
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 30,
  );
  static const double _inset = 4;
  static const double _trailingWidth = 44;
  static const double _trailingGap = 6;

  late final AnimationController _pill = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant LiquidNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _pill.animateWith(
        SpringSimulation(
          _spring,
          _pill.value,
          widget.selectedIndex.toDouble(),
          _pill.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.primary;
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

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LiquidGlass(
                  style: widget.style,
                  borderRadius: radius,
                  child: const SizedBox.expand(),
                ),
              ),
              AnimatedBuilder(
                animation: _pill,
                builder: (context, _) {
                  // Normalised travel speed: stretch along the motion, thin
                  // across it, the way the original deforms its pill.
                  final speed = (_pill.velocity / math.max(tabWidth, 1.0))
                      .clamp(-1.2, 1.2)
                      .abs();
                  return Positioned(
                    left: _inset + _pill.value * tabWidth,
                    top: _inset,
                    width: tabWidth,
                    height: pillHeight,
                    child: IgnorePointer(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                            1 + speed * 0.16,
                            1 - speed * 0.10,
                            1,
                            1,
                          ),
                        child: LiquidGlass(
                          style: _pillStyle(theme),
                          borderRadius: radius,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _LiquidNavTab(
                            destination: widget.destinations[i],
                            selected: i == widget.selectedIndex,
                            accent: accent,
                            onTap: () => widget.onDestinationSelected(i),
                          ),
                        ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: _trailingGap),
                        SizedBox(
                          width: _trailingWidth,
                          height: pillHeight,
                          child: widget.trailing,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The travelling pill. The capsule underneath already blurred the page, so
  /// this one only adds a thin lens, a little dispersion and a rim.
  GlassStyle _pillStyle(ThemeData theme) {
    return widget.style.copyWith(
      blurSigma: 4,
      refractionHeight: 14,
      refractionAmount: 12,
      depthEffect: true,
      dispersion: 0.5,
      tint: theme.brightness == Brightness.dark
          ? const Color(0x22FFFFFF)
          : const Color(0x33FFFFFF),
      sheenOpacity: 0.08,
      rimColor: theme.colorScheme.onSurface.withValues(alpha: 0.24),
      rimFalloff: 1.4,
      borderColor: const Color(0x1FFFFFFF),
    );
  }
}

class _LiquidNavTab extends StatelessWidget {
  const _LiquidNavTab({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final LiquidNavDestination destination;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? accent
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

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
                  scale: selected ? 1.08 : 1,
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
