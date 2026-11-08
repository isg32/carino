import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';

/// First run, step 2: the optional permissions, each turning on one thing.
class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationAccessProvider).value ?? false;
    final lock = ref.watch(lockAccessProvider).value ?? false;
    final calendar = ref.watch(permissionProvider('calendar')).value ?? false;
    final contacts = ref.watch(permissionProvider('contacts')).value ?? false;
    final settings = ref.read(settingsProvider.notifier);
    final pad = MediaQuery.paddingOf(context);

    void done() {
      Navigator.of(context).popUntil((r) => r.isFirst);
      settings.update((s) => s.copyWith(onboarded: true));
    }

    return CupertinoPageScaffold(
      backgroundColor: VInk.surfaceOf(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 48, 16, pad.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STEP 2 OF 2 · ALL OPTIONAL', style: VText.eyebrow),
                  const SizedBox(height: 8),
                  Text(
                    'Permissions',
                    style: VText.doto(36, weight: 800, height: 1),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Each one turns on a single thing. Nothing leaves the phone.',
                    style: VText.inter(14, weight: 300, height: 1.5),
                  ),
                ],
              ),
            ),
            VListSection(
              children: [
                _Permission(
                  icon: VIcon.bell,
                  title: 'Notification access',
                  subtitle: 'Dots on app icons',
                  on: notifications,
                  onAllow: Launcher.requestNotificationAccess,
                ),
                _Permission(
                  icon: VIcon.lock,
                  title: 'Accessibility',
                  subtitle: 'Double-tap Home to lock the screen',
                  on: lock,
                  onAllow: Launcher.requestLockAccess,
                ),
                _Permission(
                  icon: VIcon.calendar,
                  title: 'Calendar',
                  subtitle: 'Your next event on Home',
                  on: calendar,
                  onAllow: () async {
                    if (await Launcher.requestPermission('calendar')) {
                      settings.update((s) => s.copyWith(showNextEvent: true));
                      ref.invalidate(permissionProvider('calendar'));
                    }
                  },
                ),
                _Permission(
                  icon: VIcon.person,
                  title: 'Contacts',
                  subtitle: 'People in Search',
                  on: contacts,
                  onAllow: () async {
                    if (await Launcher.requestPermission('contacts')) {
                      settings.update((s) => s.copyWith(searchContacts: true));
                      ref.invalidate(permissionProvider('contacts'));
                    }
                  },
                ),
              ],
            ),
            const Spacer(),
            VButton.primary('Done', onPressed: done),
            const SizedBox(height: 10),
            const VFootnote(
              'Change any of these later in Settings.',
              center: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onAllow,
  });

  final VIcon icon;
  final String title;
  final String subtitle;
  final bool on;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return VListRow(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: VInk.of(context)),
        ),
        child: VIconView(icon, size: 18),
      ),
      title: title,
      subtitle: subtitle,
      trailing: on
          ? const VPill('On', fill: VFill.filled)
          : VPill('Allow', fill: VFill.outline, onTap: onAllow),
    );
  }
}
