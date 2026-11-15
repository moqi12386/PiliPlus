import 'package:PiliPlus/common/widgets/glass/glass_frost.dart';
import 'package:PiliPlus/common/widgets/glass/glass_style.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:material_ui/material_ui.dart';

class AppBarAni extends StatelessWidget {
  const AppBarAni({
    super.key,
    required this.child,
    required this.controller,
    required this.isTop,
    required this.isFullScreen,
    required this.removeSafeArea,
  });

  final Widget child;
  final AnimationController controller;
  final bool isTop;
  final bool isFullScreen;
  final bool removeSafeArea;

  static final _topPos = Tween<Offset>(
    begin: const Offset(0.0, -1.0),
    end: Offset.zero,
  );

  static const _topDecoration = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  static final _bottomPos = Tween<Offset>(
    begin: const Offset(0, 1.2),
    end: Offset.zero,
  );

  static const _bottomDecoration = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: controller.drive(isTop ? _topPos : _bottomPos),
      // A frosted backdrop under the existing gradient: the gradient keeps the
      // glyphs readable, the blur makes the video read as "behind glass".
      child: GlassFrost(
        style: GlassStyle.player,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isTop ? _topDecoration : _bottomDecoration,
          ),
          child: removeSafeArea
              ? child
              : ViewSafeArea(
                  left: isFullScreen,
                  right: isFullScreen,
                  child: child,
                ),
        ),
      ),
    );
  }
}
