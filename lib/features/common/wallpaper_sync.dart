import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/theme/v_colors.dart';
import '../../data/models.dart';
import 'wallpaper.dart';

/// Renders a layout's wallpaper exactly as Home draws it (palette or photo,
/// blur and dim) at [size] physical pixels, as a PNG.
///
/// With [soft], the result is heavily blurred: that is what Android itself
/// gets, so a size or crop difference in Recents and app transitions just
/// reads as a soft background. It is made cheaply by rendering a tiny copy
/// and drawing it back up through a blur.
Future<Uint8List?> renderWallpaperPng(
  HomeLayout layout,
  ui.Size size, {
  bool soft = false,
}) async {
  if (soft) {
    final small = ui.Size(
      (size.width / 6).roundToDouble(),
      (size.height / 6).roundToDouble(),
    );
    final tiny = await _render(layout, small);
    if (tiny == null) return null;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Offset.zero & size;
    // Blur a little beyond the edges so they stay as dark/bright as the rest.
    canvas.drawImageRect(
      tiny,
      ui.Offset.zero & small,
      rect.inflate(size.width * 0.06),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: size.width / 28,
          sigmaY: size.width / 28,
          tileMode: ui.TileMode.clamp,
        ),
    );
    tiny.dispose();
    return _png(recorder, size);
  }
  final image = await _render(layout, size);
  if (image == null) return null;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes?.buffer.asUint8List();
}

Future<Uint8List?> _png(ui.PictureRecorder recorder, ui.Size size) async {
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png?.buffer.asUint8List();
}

/// The wallpaper as Home draws it, as an image.
Future<ui.Image?> _render(HomeLayout layout, ui.Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rect = ui.Offset.zero & size;
  final photo = layout.wallpaper.photo;

  if (photo != null) {
    final blurred = layout.blur > 0.01 ? bakedPath(photo, layout.blur) : null;
    final file = blurred != null && File(blurred).existsSync()
        ? File(blurred)
        : File(photo);
    if (!file.existsSync()) return null;
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetHeight: size.height.round(),
    );
    final image = (await codec.getNextFrame()).image;
    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      fit: BoxFit.cover,
      filterQuality: ui.FilterQuality.high,
    );
    image.dispose();
  } else {
    paintWallpaperPalette(
      canvas,
      size,
      VWallpapers.all[layout.wallpaper.builtin] ?? VWallpapers.night,
    );
  }
  if (layout.dim > 0) {
    canvas.drawRect(
      rect,
      ui.Paint()
        ..color = VColors.black.withValues(alpha: layout.dim.clamp(0, 0.8)),
    );
  }
  return recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
}

/// What the system wallpaper was last set from, so it is only set again
/// when something that shows actually changed.
String wallpaperSignature(HomeLayout l, ui.Size size) => jsonEncode({
  'soft': 1,
  'w': l.wallpaper.toJson(),
  'd': l.dim,
  'b': l.blur,
  's': [size.width.round(), size.height.round()],
});

/// Set while a blurred photo is being made, the one wallpaper step whose
/// result you see. The shell shows [BusyOverlay] over Home meanwhile.
final wallpaperBusy = ValueNotifier<bool>(false);

Timer? _busyGuard;

/// Starts or ends [wallpaperBusy]. A guard ends it after 15 s in any case,
/// so the overlay can never be left up.
void setWallpaperBusy(bool on) {
  _busyGuard?.cancel();
  wallpaperBusy.value = on;
  if (on) {
    _busyGuard = Timer(const Duration(seconds: 10), () {
      wallpaperBusy.value = false;
    });
  }
}
