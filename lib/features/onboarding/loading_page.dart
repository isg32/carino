import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';
import '../../data/providers.dart';
import '../common/wallpaper.dart';

/// Shown while Android lists the apps for the first time (first run, or a
/// reboot with nothing cached yet): the wordmark and three Doto dots.
class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage>
    with SingleTickerProviderStateMixin {
  late final _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(activeLayoutProvider);
    final ink = VInk.of(context);
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
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  final step = (_dots.value * 3).floor();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: i <= step ? ink : null,
                            border: Border.all(color: ink),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('GETTING YOUR APPS READY', style: VText.eyebrow),
            ],
          ),
        ),
      ],
    );
  }
}
