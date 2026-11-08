import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_page.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/app_icon.dart';
import '../common/popup.dart';
import '../search/search_sheet.dart';
import '../widgets/widgets_page.dart';
import '../vault/vault.dart';
import 'about_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

/// Customise › gear.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    // Unknown until Android answers: show no card rather than a wrong one.
    final isDefault = ref.watch(defaultHomeProvider).value;
    final widgets = s.widgets.length;
    String action(GestureAction a) => _actionNames[a]!;

    return _Page(
      backLabel: 'Customise',
      title: 'Settings',
      eyebrow: 'Cariño $carinoVersion',
      children: [
        if (isDefault != null) _DefaultHomeCard(isDefault: isDefault),
        VListSection(
          children: [
            VListRow(
              leading: const _RowIcon(VIcon.home),
              title: 'Home & gestures',
              subtitle:
                  'Swipe up: ${action(s.swipeUp)} · Swipe down: ${action(s.swipeDown)}',
              onTap: () => _push(context, const HomeGesturesPage()),
            ),
            VListRow(
              leading: const _RowIcon(VIcon.apps),
              title: 'Apps & search',
              subtitle:
                  '${s.appsView == AppsView.list ? 'List' : 'Grid'} view · web: ${s.webEngine}',
              onTap: () => _push(context, const AppsSearchPage()),
            ),
            VListRow(
              leading: const _RowIcon(VIcon.widgets),
              title: 'Widgets',
              subtitle: '$widgets ${widgets == 1 ? 'widget' : 'widgets'}',
              onTap: () => showAddWidget(context),
            ),
            VListRow(
              leading: const _RowIcon(VIcon.hide),
              title: 'Hidden apps',
              subtitle: s.hidden.isEmpty
                  ? 'None hidden'
                  : '${s.hidden.length} hidden',
              onTap: () async {
                // The list shows what is hidden, so it is behind the passcode
                // too once one is set.
                if (s.hasPasscode && !await unlockHidden(context, ref)) return;
                if (context.mounted) _push(context, const HiddenAppsPage());
              },
            ),
            VListRow(
              leading: const _RowIcon(VIcon.copy),
              title: 'Backup & reset',
              subtitle: 'Export or import layouts and settings',
              onTap: () => _push(context, const BackupPage()),
            ),
            VListRow(
              leading: const _RowIcon(VIcon.info),
              title: 'About Cariño',
              subtitle: 'Version $carinoVersion · licences, developer',
              onTap: () => _push(context, const AboutPage()),
            ),
          ],
        ),
        const VFootnote(
          'Layouts, wallpaper and icons live in Customise; long-press Home to get there.',
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.backLabel,
    required this.title,
    required this.children,
    this.eyebrow,
  });

  final String backLabel;
  final String title;
  final String? eyebrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return VDetailPage(
      backLabel: backLabel,
      title: title,
      children: [
        if (eyebrow != null)
          Transform.translate(
            offset: const Offset(4, -8),
            child: Text(eyebrow!.toUpperCase(), style: VText.eyebrow),
          ),
        ...children,
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final VIcon icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: VInk.of(context)),
    ),
    child: VIconView(icon, size: 18),
  );
}

class _DefaultHomeCard extends StatelessWidget {
  const _DefaultHomeCard({required this.isDefault});

  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final paper = VInk.surfaceOf(context);
    if (!isDefault) {
      return VCard(
        outline: VOutline.dashed,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cariño isn’t your home app', style: VText.rowTitle),
                  const SizedBox(height: 2),
                  Text(
                    'The Home button opens another launcher.',
                    style: VText.secondary,
                  ),
                ],
              ),
            ),
            const VPill(
              'Fix',
              fill: VFill.filled,
              onTap: Launcher.requestDefaultHome,
            ),
          ],
        ),
      );
    }
    return VCard(
      inverted: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: paper, shape: BoxShape.circle),
            child: VIconView(
              VIcon.check,
              size: 18,
              strokeWidth: 2.25,
              color: VInk.of(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cariño is your home app',
                  style: VText.inter(15, weight: 600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Home button and gestures open Cariño.',
                  style: VText.inter(12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _actionNames = {
  GestureAction.search: 'Search',
  GestureAction.notifications: 'Notifications',
  GestureAction.customise: 'Customise',
  GestureAction.apps: 'Apps',
  GestureAction.nothing: 'Nothing',
};

Future<T?> _choose<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T value,
}) {
  return showBlurPopup<T>(
    context,
    (context) => CarinoSheet(
      title: title,
      child: VListSection(
        children: [
          for (final e in options.entries)
            VListRow(
              title: e.value,
              trailing: e.key == value
                  ? const VIconView(VIcon.check, size: 18)
                  : null,
              chevron: false,
              onTap: () => Navigator.of(context).pop(e.key),
            ),
        ],
      ),
    ),
    sheet: true,
  );
}

/// Settings › Home & gestures.
class HomeGesturesPage extends ConsumerWidget {
  const HomeGesturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    Future<void> gesture(
      String title,
      GestureAction value,
      CarinoSettings Function(GestureAction a) apply,
    ) async {
      final a = await _choose(
        context,
        title: title,
        options: _actionNames,
        value: value,
      );
      if (a != null) n.update((_) => apply(a));
    }

    return _Page(
      backLabel: 'Settings',
      title: 'Home & gestures',
      children: [
        const VEyebrow('Gestures on Home'),
        VListSection(
          children: [
            VListRow(
              title: 'Swipe up',
              value: _actionNames[s.swipeUp],
              onTap: () =>
                  gesture('Swipe up', s.swipeUp, (a) => s.copyWith(swipeUp: a)),
            ),
            VListRow(
              title: 'Swipe down',
              value: _actionNames[s.swipeDown],
              onTap: () => gesture(
                'Swipe down',
                s.swipeDown,
                (a) => s.copyWith(swipeDown: a),
              ),
            ),
            const VListRow(title: 'Long-press', value: 'Customise'),
          ],
        ),
        const VEyebrow('Clock & glance'),
        VListSection(
          children: [
            VListRow(
              title: 'Clock',
              trailing: VSegmented<bool>(
                compact: true,
                segments: const {false: '12 h', true: '24 h'},
                value: s.clock24,
                onChanged: (v) => n.update((s) => s.copyWith(clock24: v)),
              ),
            ),
            VListRow(
              title: 'Date',
              trailing: VSwitch(
                value: s.showDate,
                onChanged: (v) => n.update((s) => s.copyWith(showDate: v)),
              ),
            ),
            VListRow(
              title: 'Battery',
              trailing: VSwitch(
                value: s.showBattery,
                onChanged: (v) => n.update((s) => s.copyWith(showBattery: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Settings › Apps & search.
class AppsSearchPage extends ConsumerWidget {
  const AppsSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return _Page(
      backLabel: 'Settings',
      title: 'Apps & search',
      children: [
        const VEyebrow('Apps tab'),
        VListSection(
          children: [
            VListRow(
              title: 'Default view',
              trailing: VSegmented<AppsView>(
                compact: true,
                segments: const {AppsView.list: 'List', AppsView.grid: 'Grid'},
                value: s.appsView,
                onChanged: (v) => n.update((s) => s.copyWith(appsView: v)),
              ),
            ),
            VListRow(
              title: '“New” badges',
              subtitle: 'On apps installed in the last two days',
              trailing: VSwitch(
                value: s.newBadges,
                onChanged: (v) => n.update((s) => s.copyWith(newBadges: v)),
              ),
            ),
            VListRow(
              title: 'Scrubber haptics',
              trailing: VSwitch(
                value: s.scrubberHaptics,
                onChanged: (v) =>
                    n.update((s) => s.copyWith(scrubberHaptics: v)),
              ),
            ),
          ],
        ),
        const VEyebrow('Search'),
        VListSection(
          children: [
            VListRow(
              title: 'Opens on',
              trailing: VSegmented<SearchMode>(
                compact: true,
                segments: const {
                  SearchMode.apps: 'Apps',
                  SearchMode.essentials: 'Essentials',
                },
                value: s.searchOpensOn,
                onChanged: (v) => n.update((s) => s.copyWith(searchOpensOn: v)),
              ),
            ),
            VListRow(
              title: 'Enter opens the first app',
              trailing: VSwitch(
                value: s.enterLaunches,
                onChanged: (v) => n.update((s) => s.copyWith(enterLaunches: v)),
              ),
            ),
            VListRow(
              title: 'Search the web',
              trailing: VSwitch(
                value: s.searchWeb,
                onChanged: (v) => n.update((s) => s.copyWith(searchWeb: v)),
              ),
            ),
            VListRow(
              title: 'Web search with',
              value: s.webEngine,
              onTap: () async {
                final e = await _choose(
                  context,
                  title: 'Web search',
                  options: {for (final e in webEngines) e: e},
                  value: s.webEngine,
                );
                if (e != null) n.update((s) => s.copyWith(webEngine: e));
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Settings › Hidden apps.
class HiddenAppsPage extends ConsumerWidget {
  const HiddenAppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final apps = ref.watch(appsProvider).value ?? const [];
    return _Page(
      backLabel: 'Settings',
      title: 'Hidden apps',
      eyebrow: '${s.hidden.length} of ${apps.length} hidden',
      children: [
        VListSection(
          children: [
            VListRow(
              title: 'Passcode',
              subtitle: 'Spread two fingers on Home to open hidden apps',
              value: s.hasPasscode ? 'Change' : 'Set',
              onTap: () => s.hasPasscode
                  ? changePasscode(context, ref)
                  : unlockHidden(context, ref),
            ),
            if (s.hasPasscode)
              VListRow(
                title: 'Remove passcode',
                chevron: false,
                onTap: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Remove the passcode?',
                    body: 'The next time you open hidden apps, you’ll choose a new one.',
                    action: 'Remove passcode',
                  );
                  if (ok) {
                    n.update((s) => s.copyWith(clearPasscode: true));
                  }
                },
              ),
            VListRow(
              title: 'Find by full name in Search',
              subtitle: 'Typing the whole name still shows it',
              trailing: VSwitch(
                value: s.hiddenFindByName,
                onChanged: (v) =>
                    n.update((s) => s.copyWith(hiddenFindByName: v)),
              ),
            ),
          ],
        ),
        const VEyebrow('All apps'),
        VListSection(
          children: [
            for (final a in apps)
              VListRow(
                leading: AppGlyph(app: a, size: 32),
                title: a.label,
                trailing: VSwitch(
                  value: s.hidden.contains(a.key),
                  onChanged: (_) {
                    n.toggleHidden(a.key);
                    if (!s.hidden.contains(a.key)) {
                      ref.read(layoutsProvider.notifier).removeFromHome(a.key);
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Settings › Backup & reset.
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(prefsProvider);

    Future<void> export() async {
      final data = jsonEncode({
        'carino': 1,
        'settings': prefs.getString('settings'),
        'layouts': prefs.getString('layouts'),
      });
      await Clipboard.setData(ClipboardData(text: data));
      if (context.mounted) _toast(context, 'Copied. Paste it somewhere safe.');
    }

    Future<void> import() async {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      try {
        final j = jsonDecode(clip?.text ?? '') as Map<String, Object?>;
        if (j['carino'] != 1) throw const FormatException();
        final settings = j['settings'] as String?;
        final layouts = j['layouts'] as String?;
        if (settings != null) await prefs.setString('settings', settings);
        if (layouts != null) await prefs.setString('layouts', layouts);
        ref.invalidate(settingsProvider);
        ref.invalidate(layoutsProvider);
        if (context.mounted) _toast(context, 'Imported.');
      } catch (_) {
        if (context.mounted) {
          _toast(context, 'The clipboard doesn’t hold a Cariño backup.');
        }
      }
    }

    Future<void> reset() async {
      final ok = await confirmDialog(
        context,
        title: 'Reset Cariño?',
        body: 'Every layout and setting goes back to how it started. Apps and the system wallpaper are not touched.',
        action: 'Reset',
      );
      if (!ok) return;
      await prefs.remove('settings');
      await prefs.remove('layouts');
      ref.invalidate(settingsProvider);
      ref.invalidate(layoutsProvider);
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }

    return _Page(
      backLabel: 'Settings',
      title: 'Backup & reset',
      children: [
        const VEyebrow('Backup'),
        VListSection(
          children: [
            VListRow(
              title: 'Export',
              subtitle: 'Layouts and settings, copied as text',
              trailing: VPill('Copy', fill: VFill.outline, onTap: export),
            ),
            VListRow(
              title: 'Import',
              subtitle: 'From a backup on the clipboard',
              trailing: VPill('Paste', fill: VFill.outline, onTap: import),
            ),
          ],
        ),
        const VEyebrow('System'),
        VListSection(
          children: [
            VListRow(
              title: 'Default home app',
              onTap: () => Launcher.open('homeSettings'),
            ),
          ],
        ),
        VButton.ghost('Reset Cariño', onPressed: reset),
        const VFootnote(
          'Reset removes every layout and setting. Apps and wallpapers on the phone are not touched.',
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String text) {
  showBlurPopup<void>(context, (context) {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (context.mounted) Navigator.of(context).maybePop();
    });
    return Center(
      child: VCard(child: Text(text, style: VText.inter(14, weight: 500))),
    );
  });
}
