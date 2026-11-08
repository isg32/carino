import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/app_icon.dart';
import '../common/popup.dart';
import '../home/home_grid.dart';
import 'essentials.dart';

const _engines = {
  'DuckDuckGo': 'https://duckduckgo.com/?q=',
  'Google': 'https://www.google.com/search?q=',
  'Brave': 'https://search.brave.com/search?q=',
  'Startpage': 'https://www.startpage.com/do/search?q=',
};

List<String> get webEngines => _engines.keys.toList();

/// Swipe up on Home: one field, two modes — your apps, or your essentials.
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _query = TextEditingController();
  late SearchMode _mode = ref.read(settingsProvider).searchOpensOn;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<AppEntry> _matches(String q) {
    final settings = ref.read(settingsProvider);
    final all = ref.read(appsProvider).value ?? const [];
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final starts = <AppEntry>[];
    final contains = <AppEntry>[];
    for (final a in all) {
      final label = a.label.toLowerCase();
      if (settings.hidden.contains(a.key)) {
        if (settings.hiddenFindByName && label == needle) starts.insert(0, a);
        continue;
      }
      if (label.startsWith(needle) ||
          label.split(' ').any((w) => w.startsWith(needle))) {
        starts.add(a);
      } else if (label.contains(needle)) {
        contains.add(a);
      }
    }
    return [...starts, ...contains];
  }

  void _web(String q) {
    final engine = ref.read(settingsProvider).webEngine;
    final base = _engines[engine] ?? _engines.values.first;
    Launcher.webSearch(q, url: '$base${Uri.encodeQueryComponent(q)}');
    Navigator.of(context).maybePop();
  }

  void _submit(String q) {
    final matches = _matches(q);
    final settings = ref.read(settingsProvider);
    if (settings.enterLaunches && matches.isNotEmpty) {
      Launcher.launch(matches.first.key);
      Navigator.of(context).maybePop();
    } else if (q.trim().isNotEmpty && settings.searchWeb) {
      _web(q.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final layout = ref.watch(activeLayoutProvider);
    final ink = VInk.of(context);
    final q = _query.text.trim();
    final matches = _matches(q);

    return CarinoSheet(
      maxHeightFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VOutlined(
            radius: 24,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const VIconView(VIcon.search, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _query,
                      autofocus: true,
                      padding: EdgeInsets.zero,
                      decoration: null,
                      cursorColor: ink,
                      textInputAction: TextInputAction.search,
                      placeholder: 'Search apps and essentials',
                      placeholderStyle: VText.inter(
                        15,
                        weight: 300,
                      ).copyWith(color: ink.withValues(alpha: 0.7)),
                      style: VText.inter(15).copyWith(color: ink),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                    ),
                  ),
                  if (q.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(_query.clear),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: VIconView(VIcon.close, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          VSegmented<SearchMode>(
            segments: const {
              SearchMode.apps: 'Apps',
              SearchMode.essentials: 'Essentials',
            },
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 18),
          if (_mode == SearchMode.essentials)
            const EssentialsView()
          else if (q.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: VFootnote(
                'Type to find an app. Enter opens the first one.',
                center: true,
              ),
            )
          else ...[
            if (matches.isNotEmpty) ...[
              const VEyebrow('Apps'),
              const SizedBox(height: 12),
              _ResultGrid(
                apps: matches.take(layout.columns * 2).toList(),
                layout: layout,
              ),
              const SizedBox(height: 18),
            ],
            if (settings.searchWeb) ...[
              const VEyebrow('Elsewhere'),
              const SizedBox(height: 10),
              VListSection(
                children: [
                  VListRow(
                    title: 'Search “$q”',
                    leading: const VIconView(VIcon.globe, size: 18),
                    value: settings.webEngine,
                    onTap: () => _web(q),
                  ),
                ],
              ),
            ],
            if (matches.isEmpty && !settings.searchWeb)
              const VFootnote('No apps match.', center: true),
          ],
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.apps, required this.layout});

  final List<AppEntry> apps;
  final HomeLayout layout;

  @override
  Widget build(BuildContext context) {
    final cols = layout.columns;
    return Column(
      children: [
        for (var r = 0; r * cols < apps.length; r++) ...[
          if (r > 0) const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: homeRowPadding(cols) - 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var c = 0; c < cols; c++)
                  r * cols + c < apps.length
                      ? AppTile(
                          app: apps[r * cols + c],
                          style: layout.icons,
                          onOpened: () => Navigator.of(context).maybePop(),
                        )
                      : const SizedBox(width: homeIconSize),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
