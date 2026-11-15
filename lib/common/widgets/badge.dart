import 'package:PiliPlus/common/widgets/glass/glass_config.dart';
import 'package:PiliPlus/common/widgets/glass/glass_frost.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

class PBadge extends StatelessWidget {
  final String? text;

  final bool isStack;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final EdgeInsets? padding;

  final PBadgeType type;
  final PBadgeSize size;

  final double fontSize;
  final bool isBold;
  final double? textScaleFactor;

  /// Draws the badge as a frosted chip instead of a flat fill. Only worth using
  /// where the badge sits on top of imagery (cover art, player frames), because
  /// elsewhere there is nothing behind it to blur.
  final bool glass;

  const PBadge({
    super.key,
    required this.text,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.type = PBadgeType.primary,
    this.size = PBadgeSize.medium,
    this.isStack = true,
    this.fontSize = 11,
    this.isBold = true,
    this.textScaleFactor,
    this.padding,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isNullOrEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = ColorScheme.of(context);

    final Color bgColor;
    final Color color;
    Color borderColor = Colors.transparent;

    switch (type) {
      case PBadgeType.primary:
        bgColor = colorScheme.primary;
        color = colorScheme.onPrimary;
      case PBadgeType.secondary:
        bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.5);
        color = colorScheme.onSecondaryContainer;
      case PBadgeType.gray:
        bgColor = Colors.black45;
        color = Colors.white;
      case PBadgeType.error:
        if (colorScheme.isDark) {
          bgColor = colorScheme.errorContainer;
          color = colorScheme.onErrorContainer;
        } else {
          bgColor = colorScheme.error;
          color = colorScheme.onError;
        }
      case PBadgeType.line_primary:
        color = colorScheme.primary;
        bgColor = Colors.transparent;
        borderColor = colorScheme.primary;
      case PBadgeType.line_secondary:
        color = colorScheme.secondary;
        bgColor = Colors.transparent;
        borderColor = colorScheme.secondary;
      case PBadgeType.free:
        bgColor = colorScheme.freeColor;
        color = Colors.white;
      case PBadgeType.shop:
        bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.5);
        color = colorScheme.onSurfaceVariant;
    }

    const defPaddingStyle = EdgeInsets.symmetric(vertical: 2, horizontal: 3);
    final BorderRadius br = size == .small
        ? const .all(.circular(3))
        : const .all(.circular(4));

    final useGlass = glass && GlassConfig.enabled;

    Widget content = Container(
      padding: padding ?? defPaddingStyle,
      decoration: BoxDecoration(
        borderRadius: br,
        color: useGlass ? Colors.transparent : bgColor,
        border: .all(
          color: useGlass && borderColor == Colors.transparent
              ? const Color(0x1FFFFFFF)
              : borderColor,
        ),
      ),
      child: Text(
        text!,
        textScaler: textScaleFactor != null ? .linear(textScaleFactor!) : null,
        style: TextStyle(
          height: 1,
          fontSize: fontSize,
          color: color,
          fontWeight: isBold ? FontWeight.bold : null,
          shadows: useGlass
              ? const [Shadow(color: Color(0x66000000), blurRadius: 2)]
              : null,
        ),
        strutStyle: StrutStyle(
          leading: 0,
          height: 1,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : null,
        ),
      ),
    );

    if (useGlass) {
      // A dark tint keeps white glyphs readable over arbitrary cover art.
      content = GlassFrost(
        style: GlassStyle.pill.copyWith(
          blurSigma: 10,
          tint: Colors.black.withValues(alpha: 0.28),
          sheenOpacity: 0.04,
        ),
        borderRadius: br,
        child: content,
      );
    }
    if (isStack) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: content,
      );
    } else {
      return content;
    }
  }
}
