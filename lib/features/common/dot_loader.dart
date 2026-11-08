import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';

/// Three square Doto dots filling in turn: Cariño's "working on it".
class DotLoader extends StatefulWidget {
  const DotLoader({super.key, this.size = 10});

  final double size;

  @override
  State<DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<DotLoader>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final step = (_t.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: widget.size,
                height: widget.size,
                margin: EdgeInsets.symmetric(horizontal: widget.size / 2),
                decoration: BoxDecoration(
                  color: i <= step ? ink : null,
                  border: Border.all(color: ink),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// While [busy] is set: everything behind blurs and a small glass card
/// with the dots and [label] sits in the middle, swallowing touches. Fades
/// in and out.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.busy, required this.label});

  final ValueListenable<bool> busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: busy,
      builder: (context, on, _) => IgnorePointer(
        ignoring: !on,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: on ? 1 : 0),
          duration: Duration(milliseconds: on ? 200 : 360),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            if (t == 0) return const SizedBox.shrink();
            final palette = VPalette.of(context);
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
              child: ColoredBox(
                color: palette.popupScrim.withValues(
                  alpha: palette.popupScrim.a * t,
                ),
                child: Center(
                  child: Opacity(
                    opacity: t,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                      decoration: BoxDecoration(
                        color: palette.glassSheet,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: VInk.of(context)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DotLoader(),
                          const SizedBox(height: 16),
                          Text(label.toUpperCase(), style: VText.eyebrow),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
