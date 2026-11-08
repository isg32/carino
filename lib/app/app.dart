import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/v_theme.dart';
import '../data/providers.dart';
import '../features/home/home_scene.dart';
import '../features/onboarding/loading_page.dart';
import '../features/onboarding/welcome_page.dart';
import 'launch_blur.dart';
import 'shell.dart';

/// The app root: the active layout's ink and glass apply everywhere.
class CarinoApp extends ConsumerWidget {
  const CarinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(activeLayoutProvider);
    final palette = paletteFor(layout);
    return CupertinoApp(
      title: 'Cariño',
      debugShowCheckedModeBanner: false,
      theme: VTheme.of(palette),
      builder: (context, child) => LayoutTheme(
        layout: layout,
        child: LaunchBlur(child: child!),
      ),
      home: const _Root(),
    );
  }
}

/// Welcome until onboarded, then the shell.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    if (!onboarded) return const WelcomePage();
    // First run or a reboot with nothing cached: wait for the app list.
    final apps = ref.watch(appsProvider);
    if (!apps.hasValue) return const LoadingPage();
    return const Shell();
  }
}
