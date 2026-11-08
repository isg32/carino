import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'app/app.dart';
import 'core/theme/v_colors.dart';
import 'data/providers.dart';
import 'features/common/wallpaper.dart';
import 'features/crash_overlay.dart';
import 'features/settings/about_page.dart';
import 'platform/crash_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so errors from here on are logged and shown, not lost.
  CrashLog.instance
    ..appVersion = carinoVersion
    ..install();
  ErrorWidget.builder = quietErrorWidget;

  // Edge to edge: the wallpaper runs under the status and navigation bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: VColors.transparent,
      systemNavigationBarColor: VColors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  LicenseRegistry.addLicense(() async* {
    for (final font in ['Doto', 'Inter']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );

  // Decode the wallpaper before the first frame, so Cariño never starts on
  // an empty or half-drawn one. Meanwhile the window shows Android's own
  // (blurred) copy, so a start looks like the wallpaper coming into focus.
  final layout = container.read(activeLayoutProvider);
  final photo = layout.wallpaper.photo;
  if (photo != null) {
    await Future.wait([
      warmImage(wallpaperImage(photo, blur: layout.blur)),
      warmImage(wallpaperImage(photo, soft: true)),
    ]).timeout(const Duration(milliseconds: 1200), onTimeout: () => []);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const CarinoApp()),
  );
  // A crash on the Android side last time is shown once, now.
  unawaited(CrashLog.instance.checkLastRun());
}
