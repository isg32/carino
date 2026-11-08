# Cariño

**A quiet Android home screen.** Black and white, with your wallpaper as the only colour. Three places — Home, Apps, Widgets — and one pill to move between them.

Cariño is a launcher written in Flutter with a thin Kotlin layer. It uses Veronica's design language: pure black and white, the Doto dot-matrix face with Inter, 1 px ink outlines and frosted glass. [Launcher3](https://github.com/The-Clover-Project/packages_apps_Launcher3) is the reference for what a launcher has to do; the interface is Cariño's own.

> The package and code names are `carino` (`com.isg32.carino`); the app is called Cariño.

## Features

| Area | What it does |
| --- | --- |
| **Home** | Doto clock and date, battery, a favourites grid that shares the dock's columns, the dock. Swipe up for Search, down for notifications, long-press for Customise. Edit mode to add, remove and drag apps. |
| **Pill** | Home · Apps · Widgets in a glass capsule. The white pill follows your swipe between tabs. |
| **Apps** | Every app A–Z as a list or a grid, a letter scrubber with haptics, "New" badges and a Work section. Long-press any app for its shortcuts, Add to Home, Hide, Uninstall and App info. |
| **Widgets** | Cariño's own Clock, Battery, Calendar and Notes widgets; add, reorder, remove. |
| **Search** | One field with two modes: your apps (plus a web search), or your Essentials — quick toggles and tools you choose and order. Swipe down to close. |
| **Customise** | Long-press Home and it zooms out into its own card. Keep several layouts, each with its own wallpaper (built-in or your photos, with dim and blur), ink (white, black or auto), glass strength, mono or coloured icons, columns and favourite rows. |
| **Opening apps** | Apps slide in from the right while Cariño blurs behind them, and Cariño un-blurs when you come back. |
| **Settings** | Gestures, clock and glance line, Apps and Search options, web search engine, hidden apps, backup to the clipboard, reset. |

### Light on the battery

- Nothing redraws while Cariño is in the background; the clock ticks once a minute, on the minute, and stops when you leave.
- Battery updates are only listened to while Cariño is on screen.
- The app list and the rendered icons are cached, so after a reboot Home appears at once instead of asking Android for every app and icon again.
- Blurred backgrounds are drawn once (a blurred photo is saved as a file; the tab background is a tiny copy of the wallpaper scaled up), not recomputed every frame.

## Architecture

```
lib/
  app/         the root, the shell (tabs, pill, dock, zoom into Customise), the opening blur
  core/        Veronica's design system: tokens, colours, glass, controls, icons
  data/        models and Riverpod providers (layouts, settings, apps, battery, clock)
  features/    home, apps, widgets, search, customise, menus, settings, onboarding
  platform/    the Dart side of the Kotlin bridge
android/app/src/main/kotlin/com/isg32/carino/
  LauncherChannel.kt   apps, icons, launching, shortcuts, uninstall, wallpaper, panels, torch, battery
  MainActivity.kt      the home activity
```

Cariño talks to Android over two channels: `carino/launcher` (methods) and `carino/events` (Home pressed, packages changed, battery, torch, resume).

### Rules the tests enforce

- **Two colours.** A colour may only be created in `lib/core/theme/v_colors.dart` (built-in wallpapers included), and importing Material fails the build.

## Building

Requirements: Flutter 3.47 or later (Dart 3.13), Android SDK and JDK 17. Cariño needs Android 8.0 (API 26) or newer.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --release        # with a phone connected over USB debugging
```

Then press Home and choose Cariño, or use Settings › Backup & about › Default home app.

## Roadmap

- Android widgets from other apps on the Widgets tab
- Notification dots
- Double-tap to lock
- Contacts and system settings in Search
- Weather and next event on Home

## Contributing

Issues and pull requests are welcome. Keep each commit to one change, with a message that says why, and make sure `flutter analyze` and `flutter test` pass.
