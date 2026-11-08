import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/theme/v_tokens.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';

/// Every popup's route: what's behind blurs (with a light scrim) as the
/// popup comes in, and un-blurs as it leaves. Tapping the blur closes it.
class BlurPopupRoute<T> extends PageRoute<T> {
  BlurPopupRoute({
    required this.builder,
    this.sheet = false,
    this.blur = 14,
    this.fromScale = 0.94,
  });

  final WidgetBuilder builder;

  /// Slides up from the bottom instead of fading and growing in place.
  final bool sheet;
  final double blur;

  /// Where a centred popup grows from (a folder opens from further in).
  final double fromScale;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => 'Close';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final palette = VPalette.of(context);
    final child = builder(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blur * curved.value,
                  sigmaY: blur * curved.value,
                ),
                child: ColoredBox(
                  color: palette.popupScrim.withValues(
                    alpha: palette.popupScrim.a * curved.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (sheet)
          SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          )
        else
          FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: fromScale, end: 1.0).animate(curved),
              child: child,
            ),
          ),
      ],
    );
  }
}

Future<T?> showBlurPopup<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool sheet = false,
}) {
  HapticFeedback.lightImpact();
  return Navigator.of(context)
      .push(BlurPopupRoute<T>(builder: builder, sheet: sheet));
}

/// A glass bottom sheet with a grabber, a title and scrolling content.
/// Drag it down (or pull its content down from the top) to close it; it
/// follows the finger and springs back if let go early.
class CarinoSheet extends StatefulWidget {
  const CarinoSheet({
    super.key,
    required this.child,
    this.title,
    this.eyebrow,
    this.trailing,
    this.maxHeightFactor = 0.88,
    this.scroll = true,
  });

  final String? title;
  final String? eyebrow;
  final Widget? trailing;
  final Widget child;
  final double maxHeightFactor;
  final bool scroll;

  @override
  State<CarinoSheet> createState() => _CarinoSheetState();
}

class _CarinoSheetState extends State<CarinoSheet>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() => _drag = _from * (1 - _back.value)));
  double _from = 0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _move(double dy) {
    if (_back.isAnimating) _back.stop();
    setState(() => _drag = (_drag + dy).clamp(0.0, double.infinity));
  }

  void _release(double velocity) {
    if (_drag > 110 || velocity > 700) {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).maybePop();
      return;
    }
    _from = _drag;
    _back.forward(from: 0);
  }

  /// Content pulled down past its top drags the sheet instead.
  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification &&
        n.overscroll < 0 &&
        n.dragDetails != null) {
      _move(-n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        _drag > 0 &&
        n.dragDetails != null) {
      final dy = n.scrollDelta ?? 0;
      if (dy > 0) _move(-dy);
    } else if (n is ScrollEndNotification && _drag > 0) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final eyebrow = widget.eyebrow;
    final trailing = widget.trailing;
    final child = widget.child;
    final scroll = widget.scroll;
    final maxHeightFactor = widget.maxHeightFactor;
    final palette = VPalette.of(context);
    final ink = VInk.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (screen - keyboard) * maxHeightFactor,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) => _move(d.delta.dy),
            onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(VRadius.sheet),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.glassSheet,
                        border: Border(top: BorderSide(color: ink)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: ink,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (title != null) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (eyebrow != null) ...[
                                            Text(
                                              eyebrow.toUpperCase(),
                                              style: VText.eyebrow,
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          Text(
                                            title,
                                            style: VText.doto(
                                              30,
                                              weight: 800,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ?trailing,
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Flexible(
                              child: scroll
                                  ? SingleChildScrollView(child: child)
                                  : child,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred confirm dialog: title, what happens, the action (white pill)
/// and Cancel (outline). Resolves true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  Widget? leading,
}) async {
  final ok = await showBlurPopup<bool>(
    context,
    (context) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: () {},
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: VPalette.of(context).glassSheet,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: VInk.of(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(height: 14),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: VText.doto(28, weight: 800, height: 1.05),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: VText.inter(14, weight: 300, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    VButton.primary(
                      action,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(height: 10),
                    VButton.secondary(
                      'Cancel',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// A thin outlined track with an ink fill and a round knob, 0–1.
class CarinoSlider extends StatelessWidget {
  const CarinoSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 150,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    void set(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));
    return GestureDetector(
      onHorizontalDragUpdate: (d) => set(d.localPosition),
      onTapDown: (d) => set(d.localPosition),
      child: SizedBox(
        width: width,
        height: 28,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                border: Border.all(color: ink),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: width * value,
              height: 4,
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Positioned(
              left: (width - 20) * value,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
