import 'dart:io';
import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/theme/v_colors.dart';
import '../../data/models.dart';

/// Draws a layout's wallpaper: a built-in palette or a photo, with its dim.
class WallpaperView extends StatelessWidget {
  const WallpaperView({
    super.key,
    required this.wallpaper,
    this.dim = 0,
    this.blur = 0,
    this.soft = false,
  });

  final WallpaperRef wallpaper;
  final double dim;

  /// Blur over a photo (0–1). Shown from the file [bakeBlur] wrote; until
  /// that exists, blurred live.
  final double blur;

  /// A blurred-looking copy: photos are decoded tiny and scaled up, which
  /// reads as a heavy blur at no per-frame cost. Built-in palettes are soft
  /// already.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final photo = wallpaper.photo;
    if (photo != null && blur > 0.01 && !soft) {
      final baked = File(bakedPath(photo, blur));
      if (baked.existsSync()) {
        return _withDim(
          Image.file(baked, fit: BoxFit.cover, gaplessPlayback: true),
        );
      }
      return _withDim(
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blur * 30,
            sigmaY: blur * 30,
            tileMode: TileMode.clamp,
          ),
          child: Image.file(File(photo), fit: BoxFit.cover, cacheWidth: 720),
        ),
      );
    }
    final Widget base = photo != null
        ? Image.file(
            File(photo),
            fit: BoxFit.cover,
            cacheWidth: soft ? 40 : 1440,
            filterQuality: soft ? FilterQuality.high : FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _Palette(VWallpapers.night),
          )
        : _Palette(VWallpapers.all[wallpaper.builtin] ?? VWallpapers.night);
    return _withDim(base);
  }

  Widget _withDim(Widget base) => Stack(
    fit: StackFit.expand,
    children: [
      base,
      if (dim > 0)
        ColoredBox(color: VColors.black.withValues(alpha: dim.clamp(0, 0.8))),
    ],
  );
}

/// Where the blurred copy of [photo] at [blur] is kept.
String bakedPath(String photo, double blur) =>
    '$photo.b${(blur * 100).round()}.png';

/// Renders [photo] blurred once and saves it beside the photo, so Home shows
/// a plain image instead of blurring a full-screen photo on every frame.
Future<void> bakeBlur(String photo, double blur) async {
  if (blur <= 0.01) return;
  final out = File(bakedPath(photo, blur));
  if (out.existsSync()) return;
  final codec = await ui.instantiateImageCodec(
    await File(photo).readAsBytes(),
    targetWidth: 720,
  );
  final image = (await codec.getNextFrame()).image;
  final w = image.width.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final sigma = blur * 30 * (w / 412);
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      ),
  );
  final blurred = await recorder.endRecording().toImage(
    image.width,
    image.height,
  );
  final png = await blurred.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  blurred.dispose();
  if (png != null) await out.writeAsBytes(png.buffer.asUint8List());
}

/// Deletes a saved photo and every blurred copy of it.
Future<void> deletePhoto(String photo) async {
  final file = File(photo);
  final dir = file.parent;
  if (!dir.existsSync()) return;
  final name = file.uri.pathSegments.last;
  await for (final f in dir.list()) {
    if (f is File && f.uri.pathSegments.last.startsWith(name)) {
      await f.delete();
    }
  }
}

/// Whether a wallpaper suggests black ink.
bool wallpaperIsLight(WallpaperRef w) =>
    w.photo == null && (VWallpapers.all[w.builtin]?.light ?? false);

class _Palette extends StatelessWidget {
  const _Palette(this.palette);

  final VWallpaperPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PalettePainter(palette),
      child: const SizedBox.expand(),
    );
  }
}

class _PalettePainter extends CustomPainter {
  _PalettePainter(this.palette);

  final VWallpaperPalette palette;

  @override
  void paint(Canvas canvas, Size size) =>
      paintWallpaperPalette(canvas, size, palette);

  @override
  bool shouldRepaint(_PalettePainter old) => old.palette != palette;
}

/// Paints a built-in wallpaper: its base, then each soft blob.
void paintWallpaperPalette(
  Canvas canvas,
  Size size,
  VWallpaperPalette palette,
) {
  canvas.drawRect(Offset.zero & size, Paint()..color = palette.base);
  final longer = math.max(size.width, size.height);
  for (final b in palette.blobs) {
    final c = Offset(
      size.width / 2 + b.x * size.width / 2,
      size.height / 2 + b.y * size.height / 2,
    );
    final r = b.radius * longer;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [b.color, b.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }
}
