import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_colors.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/popup.dart';
import '../common/wallpaper.dart';
import '../home/home_scene.dart';
import '../settings/about_page.dart';
import 'layout_menu.dart';
import 'wallpaper_sheet.dart';

/// Where the active layout's card sits in Customise, so Home can zoom
/// straight into it.
abstract final class CustomiseGeometry {
  static const double gap = 14;

  static double cardWidth(Size size) => size.width * 0.42;

  static Rect cardRect(Size size, EdgeInsets padding) {
    final w = cardWidth(size);
    final h = w * size.height / size.width;
    return Rect.fromLTWH((size.width - w) / 2, padding.top + 112, w, h);
  }
}

/// Long-press Home: every layout as a card, the active one in the middle,
/// and the active layout's wallpaper, ink, glass, icons and grid below.
class CustomiseScreen extends ConsumerStatefulWidget {
  const CustomiseScreen({
    super.key,
    required this.progress,
    required this.onDone,
    required this.onSettings,
  });

  final Animation<double> progress;
  final VoidCallback onDone;
  final VoidCallback onSettings;

  @override
  ConsumerState<CustomiseScreen> createState() => _CustomiseScreenState();
}

class _CustomiseScreenState extends ConsumerState<CustomiseScreen> {
  ScrollController? _cards;

  double _offsetFor(int index, Size size) =>
      index * (CustomiseGeometry.cardWidth(size) + CustomiseGeometry.gap);

  @override
  void dispose() {
    _cards?.dispose();
    super.dispose();
  }

  Future<void> _center(int index) async {
    final c = _cards;
    if (c == null || !c.hasClients) return;
    await c.animateTo(
      _offsetFor(index, MediaQuery.sizeOf(context)),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _done() async {
    await _center(ref.read(layoutsProvider).activeIndex);
    widget.onDone();
  }

  Future<void> _tapCard(HomeLayout l, int index) async {
    final state = ref.read(layoutsProvider);
    unawaited(HapticFeedback.selectionClick());
    if (state.activeId == l.id) {
      await _done();
      return;
    }
    ref.read(layoutsProvider.notifier).setActive(l.id);
    await _center(index);
  }

  void _newLayout() {
    final notifier = ref.read(layoutsProvider.notifier);
    notifier.add();
    final index = ref.read(layoutsProvider).activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(index));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(layoutsProvider);
    final layout = state.active;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final card = CustomiseGeometry.cardRect(size, padding);
    _cards ??= ScrollController(
      initialScrollOffset: _offsetFor(state.activeIndex, size),
    );

    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(widget.progress.value);
        final content = const Interval(
          0.45,
          1,
        ).transform(widget.progress.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            // The wallpaper blurs up as Home zooms out: a cross-fade to the
            // soft copy, which costs nothing per frame.
            RepaintBoundary(
              child: WallpaperView(
                wallpaper: layout.wallpaper,
                blur: layout.blur,
              ),
            ),
            Opacity(
              opacity: t,
              child: RepaintBoundary(
                child: WallpaperView(wallpaper: layout.wallpaper, soft: true),
              ),
            ),
            ColoredBox(color: VColors.black.withValues(alpha: 0.72 * t)),
            Opacity(
              opacity: content,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - content)),
                child: child,
              ),
            ),
          ],
        );
      },
      child: DefaultTextStyle.merge(
        style: VText.body.copyWith(color: VColors.white),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: padding.top + 24,
              child: _Header(
                count: state.layouts.length,
                onSettings: widget.onSettings,
                onDone: _done,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: card.top,
              height: card.height + 34,
              child: ListView(
                controller: _cards,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: card.left),
                children: [
                  for (var i = 0; i < state.layouts.length; i++) ...[
                    if (i > 0) const SizedBox(width: CustomiseGeometry.gap),
                    _LayoutCard(
                      layout: state.layouts[i],
                      rect: card,
                      active: state.layouts[i].id == state.activeId,
                      onTap: () => _tapCard(state.layouts[i], i),
                      onLongPress: () =>
                          showLayoutMenu(context, state.layouts[i]),
                    ),
                  ],
                  const SizedBox(width: CustomiseGeometry.gap),
                  _NewCard(rect: card, onTap: _newLayout),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: card.bottom + 44,
              bottom: 0,
              child: _LayoutSettings(layout: layout),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.onSettings,
    required this.onDone,
  });

  final int count;
  final VoidCallback onSettings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count ${count == 1 ? 'LAYOUT' : 'LAYOUTS'}',
                style: VText.eyebrow,
              ),
              const SizedBox(height: 6),
              Text('Customise', style: VText.title),
            ],
          ),
        ),
        VCircleButton(icon: VIcon.gear, onTap: onSettings, size: 40),
        const SizedBox(width: 8),
        VPill(
          'Done',
          onTap: onDone,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        ),
      ],
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.layout,
    required this.rect,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final HomeLayout layout;
  final Rect rect;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Semantics(
      button: true,
      selected: active,
      label: '${layout.name} layout',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: Column(
          children: [
            Container(
              width: rect.width,
              height: rect.height,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: VColors.white, width: active ? 2 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(
                    size: size,
                    child: HomeScene(layout: layout),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              active ? '${layout.name} · in use' : layout.name,
              style: VText.inter(13, weight: 500),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCard extends StatelessWidget {
  const _NewCard({required this.rect, required this.onTap});

  final Rect rect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          VOutlined(
            radius: 22,
            outline: VOutline.dashed,
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const VIconView(VIcon.plus, size: 24),
                  const SizedBox(height: 10),
                  Text('New layout', style: VText.inter(14, weight: 500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Blank', style: VText.inter(13, weight: 500)),
        ],
      ),
    );
  }
}

class _LayoutSettings extends ConsumerWidget {
  const _LayoutSettings({required this.layout});

  final HomeLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(layoutsProvider.notifier);
    void set(HomeLayout Function(HomeLayout l) f) => n.updateLayout(f(layout));
    final wallpaperName = layout.wallpaper.photo != null
        ? 'Photo'
        : _title(layout.wallpaper.builtin ?? 'night');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        VListSection(
          children: [
            VListRow(
              title: 'Wallpaper',
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 26,
                  height: 38,
                  child: WallpaperView(wallpaper: layout.wallpaper),
                ),
              ),
              value: wallpaperName,
              onTap: () => showWallpaperSheet(context, layout),
            ),
            VListRow(
              title: 'Ink',
              trailing: VSegmented<InkMode>(
                compact: true,
                segments: const {
                  InkMode.white: 'White',
                  InkMode.black: 'Black',
                  InkMode.auto: 'Auto',
                },
                value: layout.ink,
                onChanged: (v) => set((l) => l.copyWith(ink: v)),
              ),
            ),
            VListRow(
              title: 'Glass',
              trailing: CarinoSlider(
                value: layout.glass,
                onChanged: (v) => set((l) => l.copyWith(glass: v)),
              ),
            ),
            VListRow(
              title: 'Icons',
              trailing: VSegmented<IconStyle>(
                compact: true,
                segments: const {
                  IconStyle.mono: 'Mono',
                  IconStyle.colored: 'Colored',
                },
                value: layout.icons,
                onChanged: (v) => set((l) => l.copyWith(icons: v)),
              ),
            ),
            VListRow(
              title: 'Columns',
              subtitle: 'Dock and favourites',
              trailing: VStepper(
                value: layout.columns,
                min: 3,
                max: 5,
                onChanged: (v) => set((l) => l.copyWith(columns: v)),
              ),
            ),
            VListRow(
              title: 'Favourite rows',
              trailing: VStepper(
                value: layout.favRows,
                min: 1,
                max: 3,
                onChanged: (v) => set((l) => l.copyWith(favRows: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VListSection(
          children: [
            VListRow(
              title: 'About Cariño',
              value: 'Version $carinoVersion',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const AboutPage(backLabel: 'Customise'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
