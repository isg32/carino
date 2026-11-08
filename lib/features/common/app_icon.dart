import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';

/// An app's round icon: its monochrome layer in ink on glass (or its Doto
/// initial when it has none), or the full-colour icon, per layout.
class AppGlyph extends ConsumerWidget {
  const AppGlyph({
    super.key,
    required this.app,
    this.size = 56,
    this.style = IconStyle.mono,
    this.lifted = false,
    this.blur = false,
  });

  final AppEntry app;
  final double size;
  final IconStyle style;

  /// Inverted (white fill, black glyph), for an icon being dragged.
  final bool lifted;

  /// Frosted glass behind the glyph. Only for Home and the dock, where a
  /// dozen icons sit still; never in long scrolling lists.
  final bool blur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);
    final palette = VPalette.of(context);
    final colored = style == IconStyle.colored && !lifted;
    final bytes = ref.watch(iconProvider((app.key, !colored))).value;

    if (colored && bytes != null) {
      return SizedBox.square(
        dimension: size,
        child: Image.memory(
          bytes,
          cacheWidth: 144,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    final fg = lifted ? paper : ink;
    final Widget glyph = bytes != null
        ? Image.memory(
            bytes,
            cacheWidth: 144,
            width: size * 0.62,
            height: size * 0.62,
            color: fg,
            colorBlendMode: BlendMode.srcIn,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          )
        : Text(
            app.label.isEmpty ? '?' : app.label.characters.first.toUpperCase(),
            style: VText.doto(
              size * 0.46,
              weight: 800,
              height: 1,
            ).copyWith(color: fg),
          );

    // A tint, not a live blur: dozens of icons each blurring the screen
    // behind them every frame is what made scrolling heavy.
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lifted ? ink : palette.glassCard,
        border: Border.all(color: ink),
      ),
      child: glyph,
    );
    if (!blur || lifted) return circle;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: circle,
      ),
    );
  }
}

/// An app on Home, in the dock, in grids: tap to open, long-press for the
/// app menu.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.app,
    this.size = 56,
    this.style = IconStyle.mono,
    this.label = true,
    this.onLongPress,
    this.onOpened,
    this.dot = false,
    this.blur = false,
  });

  final AppEntry app;
  final double size;
  final IconStyle style;
  final bool label;
  final bool dot;
  final void Function(BuildContext context, Rect iconRect)? onLongPress;

  /// Called after the app is asked to open (Search closes itself).
  final VoidCallback? onOpened;

  /// See [AppGlyph.blur].
  final bool blur;

  static Rect rectOf(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final icon = Builder(
      builder: (iconContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          final r = rectOf(iconContext);
          final ratio = MediaQuery.devicePixelRatioOf(iconContext);
          Launcher.launch(
            app.key,
            bounds: Rect.fromLTRB(
              r.left * ratio,
              r.top * ratio,
              r.right * ratio,
              r.bottom * ratio,
            ),
          );
          onOpened?.call();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!(iconContext, rectOf(iconContext));
              },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppGlyph(app: app, size: size, style: style, blur: blur),
            if (dot)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: VInk.of(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VInk.surfaceOf(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!label) return Semantics(label: app.label, button: true, child: icon);
    return Semantics(
      label: app.label,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 8),
            SizedBox(
              height: 16,
              child: OverflowBox(
                maxWidth: size + 28,
                minHeight: 16,
                maxHeight: 16,
                child: Text(
                  app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: VText.inter(12, weight: 500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty Home slot in edit mode: a dashed "+" circle.
class EmptySlot extends StatelessWidget {
  const EmptySlot({
    super.key,
    this.size = 56,
    this.onTap,
    this.highlight = false,
  });

  final double size;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _DashedCircle(ink, filled: highlight),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: Text(
                    '+',
                    style: VText.inter(22, weight: 300).copyWith(
                      color: highlight ? VInk.surfaceOf(context) : ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color, {this.filled = false});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 0.5;
    if (filled) {
      canvas.drawCircle(c, r, Paint()..color = color);
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashes = 28;
    const sweep = 2 * 3.14159265 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) =>
      old.color != color || old.filled != filled;
}
