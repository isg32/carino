import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_colors.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/popup.dart';
import '../common/wallpaper.dart';

enum _ApplyTo { carino, lock, both }

Future<void> showWallpaperSheet(BuildContext context, HomeLayout layout) =>
    showBlurPopup<void>(
      context,
      (_) => _WallpaperSheet(layout.id),
      sheet: true,
    );

/// Customise › Wallpaper: built-in palettes, your saved photos (long-press
/// one to delete it), dim, blur for photos, and whether to also set the
/// system wallpaper.
class _WallpaperSheet extends ConsumerStatefulWidget {
  const _WallpaperSheet(this.layoutId);

  final String layoutId;

  @override
  ConsumerState<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends ConsumerState<_WallpaperSheet> {
  _ApplyTo _apply = _ApplyTo.carino;
  WallpaperRef? _choice;
  double? _dim;
  double? _blur;
  bool _busy = false;

  HomeLayout get _layout => ref
      .read(layoutsProvider)
      .layouts
      .firstWhere((l) => l.id == widget.layoutId);

  Future<void> _pickPhoto() async {
    final path = await Launcher.pickImage();
    if (path == null || !mounted) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(photos: [path, ...s.photos]));
    setState(() => _choice = WallpaperRef.photo(path));
  }

  Future<void> _removePhoto(String path) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this photo?',
      body: 'It is removed from Cariño’s saved wallpapers. Layouts using it go back to Night. The original in your gallery is not touched.',
      action: 'Delete photo',
    );
    if (!ok || !mounted) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(photos: [...s.photos]..remove(path)));
    final layouts = ref.read(layoutsProvider.notifier);
    for (final l in ref.read(layoutsProvider).layouts) {
      if (l.wallpaper.photo == path) {
        layouts.updateLayout(
          l.copyWith(wallpaper: const WallpaperRef.builtin('night'), blur: 0),
        );
      }
    }
    if (_choice?.photo == path) setState(() => _choice = null);
    await deletePhoto(path);
  }

  /// Renders a built-in wallpaper at screen size for the system to use.
  Future<Uint8List?> _render(WallpaperRef w, double dim) async {
    final size = View.of(context).physicalSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintWallpaperPalette(
      canvas,
      size,
      VWallpapers.all[w.builtin] ?? VWallpapers.night,
    );
    if (dim > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = VColors.black.withValues(alpha: dim),
      );
    }
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> _use() async {
    final layout = _layout;
    final w = _choice ?? layout.wallpaper;
    final dim = _dim ?? layout.dim;
    final blur = w.photo == null ? 0.0 : (_blur ?? layout.blur);
    setState(() => _busy = true);
    if (w.photo != null && blur > 0.01) await bakeBlur(w.photo!, blur);
    ref
        .read(layoutsProvider.notifier)
        .updateLayout(layout.copyWith(wallpaper: w, dim: dim, blur: blur));
    if (_apply != _ApplyTo.carino) {
      final which = _apply == _ApplyTo.lock ? 'lock' : 'both';
      if (w.photo != null) {
        final file = blur > 0.01 ? bakedPath(w.photo!, blur) : w.photo!;
        await Launcher.setSystemWallpaper(file, which);
      } else {
        final png = await _render(w, dim);
        if (png != null) await Launcher.setSystemWallpaperBytes(png, which);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref
        .watch(layoutsProvider)
        .layouts
        .firstWhere((l) => l.id == widget.layoutId);
    final photos = ref.watch(settingsProvider.select((s) => s.photos));
    final chosen = _choice ?? layout.wallpaper;
    final dim = _dim ?? layout.dim;
    final blur = _blur ?? layout.blur;
    final ink = VInk.of(context);

    Widget tile(WallpaperRef w, String label, {VoidCallback? onRemove}) {
      final selected = chosen == w;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _choice = w);
        },
        onLongPress: onRemove == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onRemove();
              },
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ink, width: selected ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WallpaperView(wallpaper: w),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: ink,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: VIconView(
                          VIcon.check,
                          size: 13,
                          strokeWidth: 3,
                          color: VInk.surfaceOf(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CarinoSheet(
      eyebrow: 'Layout · ${layout.name}',
      title: 'Wallpaper',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.55,
            children: [
              for (final b in VWallpapers.all.keys)
                tile(WallpaperRef.builtin(b), b),
              for (final p in photos)
                tile(
                  WallpaperRef.photo(p),
                  'Saved photo',
                  onRemove: () => _removePhoto(p),
                ),
              GestureDetector(
                onTap: _pickPhoto,
                child: VOutlined(
                  radius: 16,
                  outline: VOutline.dashed,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const VIconView(VIcon.image, size: 22),
                      const SizedBox(height: 8),
                      Text('Photos', style: VText.inter(12, weight: 500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            const VFootnote('Long-press a saved photo to delete it.'),
          ],
          const SizedBox(height: 16),
          VListSection(
            children: [
              VListRow(
                title: 'Dim',
                trailing: CarinoSlider(
                  value: dim / 0.6,
                  onChanged: (v) => setState(() => _dim = v * 0.6),
                ),
              ),
              if (chosen.photo != null)
                VListRow(
                  title: 'Blur',
                  trailing: CarinoSlider(
                    value: blur,
                    onChanged: (v) => setState(() => _blur = v),
                  ),
                ),
              VListRow(
                title: 'Also set',
                trailing: VSegmented<_ApplyTo>(
                  compact: true,
                  segments: const {
                    _ApplyTo.carino: 'No',
                    _ApplyTo.lock: 'Lock',
                    _ApplyTo.both: 'System',
                  },
                  value: _apply,
                  onChanged: (v) => setState(() => _apply = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const VFootnote(
            '“Lock” also sets the lock screen; “System” sets the lock screen and the system wallpaper apps see.',
          ),
          const SizedBox(height: 16),
          VButton.primary(
            _busy ? 'Setting…' : 'Use wallpaper',
            onPressed: _busy ? null : _use,
          ),
        ],
      ),
    );
  }
}
