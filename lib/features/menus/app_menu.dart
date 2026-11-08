import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/app_icon.dart';
import '../common/popup.dart';

/// Long-press an app: the icon stays sharp while everything else blurs, and
/// a glass menu grows beside it with the app's shortcuts and actions.
Future<void> showAppMenu(
  BuildContext context, {
  required AppEntry app,
  required Rect iconRect,
  VoidCallback? onEditHome,
}) {
  return Navigator.of(context).push(
    BlurPopupRoute<void>(
      blur: 12,
      builder: (_) =>
          _AppMenu(app: app, iconRect: iconRect, onEditHome: onEditHome),
    ),
  );
}

class _AppMenu extends ConsumerWidget {
  const _AppMenu({required this.app, required this.iconRect, this.onEditHome});

  final AppEntry app;
  final Rect iconRect;
  final VoidCallback? onEditHome;

  static const double _width = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(activeLayoutProvider);
    final onHome =
        layout.favGrid.contains(app.key) || layout.dockRow.contains(app.key);
    final size = MediaQuery.sizeOf(context);
    final above = iconRect.top > size.height * 0.45;
    final left = (iconRect.center.dx - _width / 2).clamp(
      16.0,
      size.width - _width - 16,
    );

    void close() => Navigator.of(context).pop();

    Future<void> uninstall() async {
      final system = await Launcher.isSystemApp(app.package);
      if (!context.mounted) return;
      if (system) {
        close();
        await Launcher.appInfo(app.key);
        return;
      }
      final ok = await confirmDialog(
        context,
        title: 'Uninstall ${app.label}?',
        body: 'The app and its data are removed from this phone. Its spot on Home stays empty until you fill it.',
        action: 'Uninstall',
        leading: AppGlyph(app: app, size: 64),
      );
      if (ok) await Launcher.uninstall(app.package);
      if (context.mounted) close();
    }

    final actions = <_Action>[
      if (onHome)
        _Action('Remove', VIcon.minus, () {
          ref.read(layoutsProvider.notifier).removeFromHome(app.key);
          close();
        })
      else
        _Action('Add to Home', VIcon.plus, () {
          final ok = ref.read(layoutsProvider.notifier).pinToHome(app.key);
          close();
          if (!ok) {
            showBlurPopup<void>(
              context,
              (_) => const CarinoSheet(
                title: 'Home is full',
                child: Text(
                  'Remove an app from Home, or add a favourite row in Customise.',
                ),
              ),
              sheet: true,
            );
          }
        }),
      if (onEditHome != null)
        _Action('Edit Home', VIcon.edit, () {
          close();
          onEditHome!();
        }),
      _Action('Hide', VIcon.hide, () {
        ref.read(settingsProvider.notifier).toggleHidden(app.key);
        ref.read(layoutsProvider.notifier).removeFromHome(app.key);
        close();
      }),
      _Action('Uninstall', VIcon.trash, uninstall, primary: true),
    ];

    final menu = _MenuCard(
      app: app,
      actions: actions,
      notifications: ref.watch(dotsProvider).value?[app.package] ?? 0,
      onInfo: () {
        close();
        Launcher.appInfo(app.key);
      },
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          width: _width,
          top: above ? null : iconRect.bottom + 34,
          bottom: above ? size.height - iconRect.top + 14 : null,
          child: menu,
        ),
        Positioned.fromRect(
          rect: iconRect,
          child: IgnorePointer(
            child: AppGlyph(
              app: app,
              size: iconRect.width,
              style: layout.icons,
            ),
          ),
        ),
      ],
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.onTap, {this.primary = false});

  final String label;
  final VIcon icon;
  final VoidCallback onTap;
  final bool primary;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.app,
    required this.actions,
    this.notifications = 0,
    required this.onInfo,
  });

  final AppEntry app;
  final List<_Action> actions;
  final int notifications;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: VPalette.of(context).glassSheet,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ink),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VText.inter(15, weight: 600),
                        ),
                      ),
                      if (notifications > 0) ...[
                        VPill('$notifications new', fill: VFill.filled),
                        const SizedBox(width: 4),
                      ],
                      Semantics(
                        button: true,
                        label: 'App info',
                        child: GestureDetector(
                          onTap: onInfo,
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: VIconView(VIcon.info, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VDivider(),
                _Shortcuts(app: app),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                  child: Row(
                    children: [
                      for (final a in actions)
                        Expanded(
                          child: VTappable(
                            onTap: a.onTap,
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: a.primary ? ink : null,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ink),
                                  ),
                                  child: VIconView(
                                    a.icon,
                                    size: 18,
                                    color: a.primary ? paper : ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.label,
                                  maxLines: 1,
                                  style: VText.inter(11, weight: 500),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.app});

  final AppEntry app;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppShortcut>>(
      future: Launcher.shortcuts(app.key),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final s in list) ...[
              VTappable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                  Launcher.startShortcut(app.key, s.id);
                },
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      const VIconView(VIcon.external, size: 16),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VText.inter(14, weight: 500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VDivider(),
            ],
          ],
        );
      },
    );
  }
}
