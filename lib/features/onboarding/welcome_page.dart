import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../common/wallpaper.dart';
import 'permissions_page.dart';

/// First launch, step 1: what Cariño is, and one primary action.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(activeLayoutProvider);
    final pad = MediaQuery.paddingOf(context);
    // Step 2: the optional permissions.
    void next() => Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const PermissionsPage()));

    return Stack(
      fit: StackFit.expand,
      children: [
        WallpaperView(wallpaper: layout.wallpaper),
        Padding(
          padding: EdgeInsets.fromLTRB(28, pad.top + 72, 28, pad.bottom + 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('A QUIET HOME SCREEN', style: VText.eyebrow),
              const SizedBox(height: 14),
              Text('Cariño', style: VText.doto(84, weight: 900, height: 0.95)),
              const SizedBox(height: 20),
              Text(
                'Black and white, with your wallpaper as the only colour. Three places, one pill.',
                style: VText.inter(17, weight: 300, height: 1.5),
              ),
              const SizedBox(height: 36),
              const VListSection(
                children: [
                  _Point(
                    VIcon.apps,
                    'Home, Apps, Widgets',
                    'Swipe or tap the pill to move between them',
                  ),
                  _Point(
                    VIcon.search,
                    'Swipe up to search',
                    'Apps, the web and your essentials',
                  ),
                  _Point(
                    VIcon.image,
                    'Hold to customise',
                    'Keep several layouts, each with its wallpaper',
                  ),
                ],
              ),
              const Spacer(),
              VButton.primary(
                'Set as home app',
                onPressed: () async {
                  await Launcher.requestDefaultHome();
                  next();
                },
              ),
              const SizedBox(height: 10),
              VButton.ghost('Look around first', onPressed: next),
            ],
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.title, this.subtitle);

  final VIcon icon;
  final String title;
  final String subtitle;

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
    );
  }
}
