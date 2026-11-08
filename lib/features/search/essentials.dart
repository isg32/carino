import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_page.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';

/// Something in Search › Essentials: a toggle (round button) or a tool (row).
class Essential {
  const Essential(this.id, this.label, this.icon, this.toggle, this.run);

  final String id;
  final String label;
  final VIcon icon;
  final bool toggle;
  final Future<void> Function(WidgetRef ref) run;
}

final essentialsCatalog = <String, Essential>{
  for (final e in [
    Essential('wifi', 'Wi-Fi', VIcon.wifi, true, (_) => Launcher.panel('wifi')),
    Essential(
      'internet',
      'Internet',
      VIcon.internet,
      true,
      (_) => Launcher.panel('internet'),
    ),
    Essential(
      'bluetooth',
      'Bluetooth',
      VIcon.bluetooth,
      true,
      (_) => Launcher.panel('bluetooth'),
    ),
    Essential('torch', 'Torch', VIcon.torch, true, (ref) async {
      final on = ref.read(torchProvider).value ?? false;
      await Launcher.torch(!on);
    }),
    Essential('dnd', 'Focus', VIcon.moon, true, (_) => Launcher.panel('dnd')),
    Essential(
      'volume',
      'Volume',
      VIcon.volume,
      true,
      (_) => Launcher.panel('volume'),
    ),
    Essential(
      'timer',
      'Timer',
      VIcon.timer,
      false,
      (_) => Launcher.open('timer'),
    ),
    Essential(
      'alarm',
      'New alarm',
      VIcon.alarm,
      false,
      (_) => Launcher.open('alarm'),
    ),
    Essential(
      'camera',
      'Camera',
      VIcon.camera,
      false,
      (_) => Launcher.open('camera'),
    ),
    Essential(
      'calendar',
      'Calendar',
      VIcon.calendar,
      false,
      (_) => Launcher.open('calendar'),
    ),
    Essential(
      'settings',
      'System settings',
      VIcon.gear,
      false,
      (_) => Launcher.open('settings'),
    ),
  ])
    e.id: e,
};

/// Search › Essentials › Edit: reorder, remove, add.
class EssentialsEditPage extends ConsumerWidget {
  const EssentialsEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(settingsProvider.select((s) => s.essentials));
    final n = ref.read(settingsProvider.notifier);
    final current = [for (final id in ids) ?essentialsCatalog[id]];
    final more = [
      for (final e in essentialsCatalog.values)
        if (!ids.contains(e.id)) e,
    ];
    void set(List<String> list) =>
        n.update((s) => s.copyWith(essentials: list));

    return VDetailPage(
      backLabel: 'Search',
      title: 'Essentials',
      children: [
        const VEyebrow('In Essentials · drag to reorder'),
        if (current.isEmpty)
          const VFootnote('Nothing yet. Add toggles and tools below.')
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: VInk.of(context)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ReorderableList(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                proxyDecorator: (child, _, _) => child,
                itemCount: current.length,
                onReorderItem: (int from, int to) {
                  final list = [for (final e in current) e.id];
                  list.insert(to, list.removeAt(from));
                  set(list);
                },
                itemBuilder: (context, i) => _EditRow(
                  key: ValueKey(current[i].id),
                  essential: current[i],
                  index: i,
                  first: i == 0,
                  onRemove: () => set([...ids]..remove(current[i].id)),
                ),
              ),
            ),
          ),
        if (more.isNotEmpty) ...[
          const SizedBox(height: 8),
          const VEyebrow('Add'),
          VListSection(
            children: [
              for (final e in more)
                VListRow(
                  title: e.label,
                  subtitle: e.toggle ? 'Toggle' : 'Tool',
                  leading: VIconView(e.icon, size: 18),
                  trailing: const VIconView(VIcon.plus, size: 18),
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    set([...ids, e.id]);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.essential,
    required this.index,
    required this.first,
    required this.onRemove,
  });

  final Essential essential;
  final int index;
  final bool first;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VInk.surfaceOf(context).withValues(alpha: 0.001),
        border: first ? null : Border(top: BorderSide(color: ink)),
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Remove ${essential.label}',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                  child: Container(
                    width: 10,
                    height: 2,
                    color: VInk.surfaceOf(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            VIconView(essential.icon, size: 18),
            const SizedBox(width: 14),
            Expanded(child: Text(essential.label, style: VText.rowTitle)),
            Text(essential.toggle ? 'Toggle' : 'Tool', style: VText.secondary),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: VIconView(VIcon.drag, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round toggles and tool rows shown in Search › Essentials.
class EssentialsView extends ConsumerWidget {
  const EssentialsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(settingsProvider.select((s) => s.essentials));
    final torch = ref.watch(torchProvider).value ?? false;
    final items = [for (final id in ids) ?essentialsCatalog[id]];
    final toggles = [
      for (final e in items)
        if (e.toggle) e,
    ];
    final tools = [
      for (final e in items)
        if (!e.toggle) e,
    ];
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);

    Future<void> run(Essential e) async {
      unawaited(HapticFeedback.selectionClick());
      await e.run(ref);
      if (e.id != 'torch' && context.mounted) {
        unawaited(Navigator.of(context).maybePop());
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toggles.isNotEmpty) ...[
          const VEyebrow('Toggles'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: [
              for (final e in toggles)
                GestureDetector(
                  onTap: () => run(e),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e.id == 'torch' && torch ? ink : null,
                            border: Border.all(color: ink),
                          ),
                          child: VIconView(
                            e.icon,
                            size: 22,
                            color: e.id == 'torch' && torch ? paper : ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.label,
                          style: VText.inter(12, weight: 500),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (tools.isNotEmpty) ...[
          const VEyebrow('Tools'),
          const SizedBox(height: 10),
          VListSection(
            children: [
              for (final e in tools)
                VListRow(
                  title: e.label,
                  leading: VIconView(e.icon, size: 18),
                  onTap: () => run(e),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Center(
          child: VLink(
            'Edit Essentials',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => const EssentialsEditPage(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
