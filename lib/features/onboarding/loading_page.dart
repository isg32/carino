import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/v_text.dart';
import '../../data/providers.dart';
import '../common/dot_loader.dart';
import '../common/wallpaper.dart';

/// Shown while Android lists the apps for the first time (first run, or a
/// reboot with nothing cached yet): the wordmark and the Doto dots.
class LoadingPage extends ConsumerWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(activeLayoutProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        WallpaperView(
          wallpaper: layout.wallpaper,
          dim: layout.dim,
          blur: layout.blur,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cariño', style: VText.doto(64, weight: 900, height: 1)),
              const SizedBox(height: 24),
              const DotLoader(),
              const SizedBox(height: 20),
              Text('GETTING YOUR APPS READY', style: VText.eyebrow),
            ],
          ),
        ),
      ],
    );
  }
}
