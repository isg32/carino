import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/app_icon.dart';
import '../home/home_grid.dart';

/// The Apps tab: every app A–Z as a list or a grid, with a letter scrubber.
class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({
    super.key,
    required this.bottomClearance,
    required this.onMenu,
  });

  final double bottomClearance;
  final SlotMenu onMenu;

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  String? _scrubbing;

  /// Section heights, so only visible sections are built and the scrubber
  /// can still jump to any of them exactly.
  static const double _labelBlock = 22 + 22 + 10;
  static const double _rowHeight = 56;
  static const double _tileHeight = homeIconSize + 8 + 16;
  static const double _tileGap = 18;

  double _extent(int count, bool grid, int columns) {
    if (grid) {
      final rows = (count / columns).ceil();
      return _labelBlock + rows * _tileHeight + (rows - 1) * _tileGap;
    }
    return _labelBlock + count * _rowHeight + (count - 1);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(String letter, List<String> letters, List<double> extents) {
    // The nearest section at or after the letter.
    final target = letters.firstWhere(
      (l) => l.compareTo(letter) >= 0,
      orElse: () => letters.last,
    );
    if (_scrubbing != target) {
      if (ref.read(settingsProvider).scrubberHaptics) {
        HapticFeedback.selectionClick();
      }
      setState(() => _scrubbing = target);
    }
    final header = _headerKey.currentContext?.size?.height ?? 0;
    final index = letters.indexOf(target);
    var offset = header;
    for (var i = 0; i < index; i++) {
      offset += extents[i];
    }
    if (_scroll.hasClients) {
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final apps = ref.watch(visibleAppsProvider);
    final loading = ref.watch(appsProvider).isLoading && apps.isEmpty;
    final settings = ref.watch(settingsProvider);
    final layout = ref.watch(activeLayoutProvider);
    final grid = settings.appsView == AppsView.grid;
    final top = MediaQuery.paddingOf(context).top;

    final personal = [
      for (final a in apps)
        if (!a.work) a,
    ];
    final work = [
      for (final a in apps)
        if (a.work) a,
    ];
    final sections = <String, List<AppEntry>>{};
    for (final a in personal) {
      (sections[a.section] ??= []).add(a);
    }
    final letters = sections.keys.toList()..sort();
    final groups = [
      for (final l in letters) (l, sections[l]!),
      if (work.isNotEmpty) ('Work', work),
    ];
    final extents = [
      for (final g in groups) _extent(g.$2.length, grid, layout.columns),
    ];

    Widget section(String label, List<AppEntry> list) => Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SizedBox(
              height: 22,
              child: Text(label, style: VText.doto(22, weight: 700, height: 1)),
            ),
          ),
          if (grid)
            _AppGrid(apps: list, layout: layout, onMenu: widget.onMenu)
          else
            _AppList(
              apps: list,
              onMenu: widget.onMenu,
              badges: settings.newBadges,
            ),
        ],
      ),
    );

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              key: _headerKey,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 24, 40, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${apps.length} APPS', style: VText.eyebrow),
                          const SizedBox(height: 6),
                          Text('Apps', style: VText.title),
                        ],
                      ),
                    ),
                    VSegmented<AppsView>(
                      compact: true,
                      segments: const {
                        AppsView.list: 'List',
                        AppsView.grid: 'Grid',
                      },
                      value: settings.appsView,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .update((s) => s.copyWith(appsView: v)),
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ),
            SliverVariedExtentList.builder(
              itemCount: groups.length,
              itemExtentBuilder: (i, _) =>
                  i < extents.length ? extents[i] : null,
              itemBuilder: (context, i) => section(groups[i].$1, groups[i].$2),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: widget.bottomClearance + 20),
            ),
          ],
        ),
        if (letters.length > 1)
          Positioned(
            right: 4,
            top: top + 110,
            bottom: widget.bottomClearance + 10,
            child: _Scrubber(
              letters: letters,
              active: _scrubbing,
              onLetter: (l) => _jump(l, letters, extents),
              onEnd: () => setState(() => _scrubbing = null),
            ),
          ),
      ],
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({
    required this.apps,
    required this.onMenu,
    required this.badges,
  });

  final List<AppEntry> apps;
  final SlotMenu onMenu;
  final bool badges;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 40, 0),
      child: VOutlined(
        radius: 18,
        child: Column(
          children: [
            for (var i = 0; i < apps.length; i++) ...[
              if (i > 0) const VDivider(),
              _AppRow(
                app: apps[i],
                onMenu: onMenu,
                badge: badges && apps[i].isNew,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onMenu, required this.badge});

  final AppEntry app;
  final SlotMenu onMenu;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (rowContext) => VTappable(
        onTap: () => Launcher.launch(app.key),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          final box = rowContext.findRenderObject()! as RenderBox;
          final origin = box.localToGlobal(const Offset(16, 11));
          onMenu(rowContext, app, origin & const Size(34, 34));
        },
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                AppGlyph(app: app, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VText.rowTitle,
                  ),
                ),
                if (app.paused) Text('Paused', style: VText.secondary),
                if (badge) const VPill('New', fill: VFill.filled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({
    required this.apps,
    required this.layout,
    required this.onMenu,
  });

  final List<AppEntry> apps;
  final HomeLayout layout;
  final SlotMenu onMenu;

  @override
  Widget build(BuildContext context) {
    final cols = layout.columns;
    final rows = <List<AppEntry>>[];
    for (var i = 0; i < apps.length; i += cols) {
      rows.add(apps.sublist(i, (i + cols).clamp(0, apps.length)));
    }
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: homeRowPadding(cols)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var c = 0; c < cols; c++)
                    c < rows[r].length
                        ? AppTile(
                            app: rows[r][c],
                            style: layout.icons,
                            onLongPress: (ctx, rect) =>
                                onMenu(ctx, rows[r][c], rect),
                          )
                        : const SizedBox(width: homeIconSize),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.letters,
    required this.active,
    required this.onLetter,
    required this.onEnd,
  });

  final List<String> letters;
  final String? active;
  final ValueChanged<String> onLetter;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        void pick(double dy) {
          final i = (dy / box.maxHeight * letters.length).floor().clamp(
            0,
            letters.length - 1,
          );
          onLetter(letters[i]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => pick(d.localPosition.dy),
          onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
          onVerticalDragEnd: (_) => onEnd(),
          onTapDown: (d) => pick(d.localPosition.dy),
          onTapUp: (_) => onEnd(),
          child: SizedBox(
            width: 28,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in letters)
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: l == active ? ink : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      l,
                      style: VText.inter(
                        10,
                        weight: 600,
                      ).copyWith(color: l == active ? paper : ink),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
