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
Future<Uint8List?> renderWallpaperPng(HomeLayout layout, ui.Size size) async {
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
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png?.buffer.asUint8List();
}

/// What the system wallpaper was last set from, so it is only set again
/// when something that shows actually changed.
String wallpaperSignature(HomeLayout l, ui.Size size) => jsonEncode({
  'w': l.wallpaper.toJson(),
  'd': l.dim,
  'b': l.blur,
  's': [size.width.round(), size.height.round()],
});
