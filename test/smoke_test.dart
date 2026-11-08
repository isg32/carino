import 'dart:convert';

import 'package:carino/app/shell.dart';
import 'package:carino/core/theme/v_theme.dart';
import 'package:carino/data/models.dart';
import 'package:carino/data/providers.dart';
import 'package:carino/features/home/home_scene.dart';
import 'package:carino/features/onboarding/loading_page.dart';
import 'package:carino/features/onboarding/permissions_page.dart';
import 'package:carino/features/onboarding/welcome_page.dart';
import 'package:carino/features/search/essentials.dart';
import 'package:carino/features/search/search_sheet.dart';
import 'package:carino/features/settings/about_page.dart';
import 'package:carino/features/settings/settings_page.dart';
import 'package:carino/features/settings/weather_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen on a phone-sized view, with white ink and with black
/// ink, and fails on any exception or layout overflow. Android's side is
/// mocked: a handful of apps, no permissions, nothing playing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final apps = [
    for (final (i, label) in const [
      'Calculator',
      'Calendar',
      'Camera',
      'Chrome',
      'Clock',
      'Gmail',
      'Maps',
      'Messages',
      'Phone',
      'Photos',
      'Settings',
      'Spotify',
      'WhatsApp',
      'YouTube',
    ].indexed)
      {
        'key': 'com.example.app$i/.Main#0',
        'package': 'com.example.app$i',
        'label': label,
        'installed': 0,
        'work': false,
        'paused': false,
      },
  ];

  Object? launcher(MethodCall call) => switch (call.method) {
    'apps' => apps,
    'isDefaultHome' ||
    'hasNotificationAccess' ||
    'hasLockAccess' ||
    'hasPermission' ||
    'torchState' => false,
    'dots' => <String, int>{},
    'battery' => {'level': 82, 'charging': false},
    'upNext' => {'events': <Object>[], 'alarm': null},
    'shortcuts' || 'searchContacts' => <Object>[],
    _ => null,
  };

  setUp(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('carino/launcher'),
      (call) async => launcher(call),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('carino/widgets'),
      (call) async => call.method == 'providers' ? <Object>[] : null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('carino/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    required InkMode ink,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final layout = HomeLayout(id: 'night', name: 'Night', ink: ink);
    SharedPreferences.setMockInitialValues({
      'settings': jsonEncode(const CarinoSettings(onboarded: true).toJson()),
      'layouts': jsonEncode({
        'layouts': [layout.toJson()],
        'active': 'night',
        'seeded': true,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final palette = paletteFor(layout);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: CupertinoApp(
          theme: VTheme.of(palette),
          builder: (context, child) =>
              LayoutTheme(layout: layout, child: child!),
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Dispose everything so no timer (clock, wallpaper sync) is left.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  final screens = <String, Widget Function()>{
    'Welcome': () => const WelcomePage(),
    'Permissions': () => const PermissionsPage(),
    'Loading': () => const LoadingPage(),
    'Home': () => const Shell(),
    'Search': () => const SearchSheet(),
    'Edit Essentials': () => const EssentialsEditPage(),
    'Settings': () => const SettingsPage(),
    'Home & gestures': () => const HomeGesturesPage(),
    'Apps & search': () => const AppsSearchPage(),
    'Hidden apps': () => const HiddenAppsPage(),
    'Backup & reset': () => const BackupPage(),
    'Weather': () => const WeatherSettingsPage(),
    'About': () => const AboutPage(),
  };

  for (final ink in [InkMode.white, InkMode.black]) {
    group('${ink.name} ink', () {
      for (final e in screens.entries) {
        testWidgets('${e.key} opens', (tester) async {
          await open(tester, e.value(), ink: ink);
        });
      }

      testWidgets('Customise, Apps and Widgets open', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        final layout = HomeLayout(id: 'night', name: 'Night', ink: ink);
        SharedPreferences.setMockInitialValues({
          'settings': jsonEncode(
            const CarinoSettings(onboarded: true).toJson(),
          ),
          'layouts': jsonEncode({
            'layouts': [layout.toJson()],
            'active': 'night',
            'seeded': true,
          }),
        });
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [prefsProvider.overrideWithValue(prefs)],
            child: CupertinoApp(
              theme: VTheme.of(paletteFor(layout)),
              builder: (context, child) =>
                  LayoutTheme(layout: layout, child: child!),
              home: const Shell(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        // Long-press Home: it zooms out into Customise.
        await tester.longPressAt(const Offset(200, 420));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Customise'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.bySemanticsLabel('Apps'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Calculator'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.bySemanticsLabel('Widgets'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('NOW PLAYING'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      });
    });
  }
}
