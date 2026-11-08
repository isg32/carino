import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../platform/launcher.dart';

/// Opening an app: it slides in from the right (a native animation) while
/// Cariño blurs behind it; coming back, Cariño un-blurs.
class LaunchBlur extends StatefulWidget {
  const LaunchBlur({super.key, required this.child});

  final Widget child;

  static const double maxSigma = 22;

  @override
  State<LaunchBlur> createState() => _LaunchBlurState();
}

class _LaunchBlurState extends State<LaunchBlur>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 420),
  );

  bool _left = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Launcher.opening.addListener(_changed);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    Launcher.opening.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _t.dispose();
    super.dispose();
  }

  void _changed() {
    if (Launcher.opening.value) {
      _left = false;
      _t.forward();
      // If nothing actually took the screen, don't stay blurred.
      _fallback?.cancel();
      _fallback = Timer(const Duration(milliseconds: 1500), () {
        if (!_left) Launcher.opening.value = false;
      });
    } else {
      _t.reverse();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _left = true;
        // Hold the blur while away, so the way back starts from it.
        if (Launcher.opening.value) _t.value = 1;
      case AppLifecycleState.resumed:
        if (Launcher.opening.value) {
          // Let the closing app clear the screen, then un-blur.
          Future.delayed(const Duration(milliseconds: 120), () {
            Launcher.opening.value = false;
          });
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        // Same tree at every value (the filter is just disabled at 0), so
        // nothing below is rebuilt when the blur starts.
        final t = Curves.easeOutCubic.transform(_t.value);
        final sigma = LaunchBlur.maxSigma * t;
        return ImageFiltered(
          enabled: sigma > 0.1,
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Transform.scale(scale: 1 - 0.04 * t, child: child),
        );
      },
    );
  }
}
