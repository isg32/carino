# Changelog

Every release is built and signed by CI from `main`; versions follow `pubspec.yaml` (minor for features, patch for fixes).

## [1.7.2] — First stable release

Cariño's first stable release: a quiet Android home screen, black and white, with your wallpaper as the only colour. Three places, Home, Apps and Widgets, under one glass pill.

### Home
- The Doto clock and date, and a glance line: weather, battery and your next calendar event, each optional.
- A favourites grid that shares the dock's columns, and the dock below the pill.
- Swipe up for Search, swipe down for notifications, double-tap to lock, long-press for Customise, spread two fingers for hidden apps.
- Edit mode: remove apps, fill empty slots, drag to rearrange between the grid and the dock.

### Apps
- Every app A–Z as a list or a grid, with a letter scrubber and haptics, "New" badges and a Work section.
- Long-press any app for its own shortcuts, Add to Home, Hide, Uninstall and App info.
- Notification dots, counted as Launcher3 does: only apps that allow dots, never ongoing notifications.

### Widgets
- Cariño's own widgets: Now playing (any app's music, with seek, pause and next), Up next (today's events and the next alarm), Clock, Weather, Battery, Calendar and Notes, each full width or small, two to a row.
- Widgets from your other apps, hosted as Launcher3 does, in their own colours inside a dashed frame; sizes S–XL, Configure, and scrolling inside list widgets.

### Search
- Apps, people (if allowed), system settings ("wifi", "battery") and the web, in one field.
- Essentials: your own toggles and tools (Wi-Fi, Bluetooth, torch, Focus, timer…), in the order you choose.

### Customise
- Long-press Home and it zooms out into its own card among your layouts.
- Each layout has its own wallpaper (built-in, or your photos with dim and blur), ink (white, black or auto), glass strength, mono or coloured icons, frosted icon backgrounds, columns and favourite rows.
- Wallpapers change the moment you choose them and cross-fade in; Android's own wallpaper follows as a soft blurred copy, so Recents and app transitions match.

### Privacy and the phone
- Hidden apps behind a passcode (a salted hash; never stored as is).
- Calendar, contacts, notification access, accessibility and location are all optional, asked for in first run or Settings, each turning on one thing.
- Weather is off until you turn it on: the one thing that uses the internet, sending only coordinates to Open-Meteo at most every 30 minutes.
- Light on the battery: nothing redraws in the background, the clock ticks once a minute, blurs are made once, and the app list and icons are cached so Home appears at once after a reboot.

### And
- Apps open sliding in from the right while Cariño blurs behind them.
- A calm crash popup with the log (copy, save to Downloads), and a report on the next launch after a native crash.
- First run: set Cariño as your home app, then one page of optional permissions.
- About, with licences, the developer and the source.

### Fixed since 1.7.0
- The music note icon's first note had its stem through its head.
- A spacing mistake in About's footnote.
- CI caches Gradle and retries when its download times out, and release notes now come from this changelog.

## [1.7.1]
- Fixed the music note icon.

## [1.7.0]
- Crash popup with the log; native crashes are shown on the next launch.

## [1.6.0]
- Cariño's own widgets can be small, two to a row.

## [1.5.2]
- Widgets with a list of their own scroll inside themselves.

## [1.5.1]
- A smoke test opens every screen in both inks.

## [1.5.0]
- Weather, off until you turn it on.

## [1.4.1]
- The screens and features map in the README.

## [1.4.0]
- Up next widget.

## [1.3.0]
- Now playing widget.

## [1.2.1]
- A widget's app is no longer named twice.

## [1.2.0]
- Optional permissions in first run.

## [1.1.0]
- Widgets from other apps on the Widgets tab.

## [1.0.0]
- The first build: Home, Apps, Widgets, Search, Customise, Settings, notification dots, double-tap to lock, the next event on Home, and people and settings in Search.
