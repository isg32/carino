import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/weather.dart';

/// Dart side of `LauncherChannel.kt`: everything Cariño asks of Android.
abstract final class Launcher {
  static const _methods = MethodChannel('carino/launcher');
  static const _events = EventChannel('carino/events');

  static Stream<Map<Object?, Object?>>? _stream;

  /// Home pressed, packages changed, battery, torch and resume events.
  static Stream<Map<Object?, Object?>> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((Object? e) => e! as Map<Object?, Object?>)
      .asBroadcastStream();

  /// True from the moment an app is opened until Cariño is back in front;
  /// the app root blurs while it is set.
  static final opening = ValueNotifier<bool>(false);

  static Future<List<AppEntry>> apps() async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>('apps');
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        AppEntry.fromMap(m),
    ];
  }

  /// PNG bytes of an app's icon: its monochrome layer in white when [mono]
  /// (null if it has none), else the full icon cut to a circle.
  static Future<Uint8List?> icon(
    String key, {
    required int size,
    bool mono = false,
  }) => _methods.invokeMethod<Uint8List>('icon', {
    'key': key,
    'size': size,
    'mono': mono,
  });

  static Future<bool> launch(String key, {Rect? bounds}) async {
    opening.value = true;
    final ok = await _methods.invokeMethod<bool>('launch', {
      'key': key,
      if (bounds != null)
        'bounds': [
          bounds.left.round(),
          bounds.top.round(),
          bounds.right.round(),
          bounds.bottom.round(),
        ],
    });
    if (ok != true) opening.value = false;
    return ok ?? false;
  }

  static Future<void> appInfo(String key) =>
      _methods.invokeMethod('appInfo', {'key': key});

  static Future<void> uninstall(String package) =>
      _methods.invokeMethod('uninstall', {'package': package});

  static Future<bool> isSystemApp(String package) async =>
      await _methods.invokeMethod<bool>('isSystemApp', {'package': package}) ??
      false;

  static Future<List<AppShortcut>> shortcuts(String key) async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'shortcuts',
      {'key': key},
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        AppShortcut(m['id']! as String, m['label']! as String),
    ];
  }

  static Future<void> startShortcut(String key, String id) {
    opening.value = true;
    return _methods.invokeMethod('startShortcut', {'key': key, 'id': id});
  }

  static Future<bool> isDefaultHome() async =>
      await _methods.invokeMethod<bool>('isDefaultHome') ?? false;

  static Future<void> requestDefaultHome() =>
      _methods.invokeMethod('requestDefaultHome');

  static Future<void> expandNotifications() =>
      _methods.invokeMethod('expandNotifications');

  /// Opens the system photo picker and returns a copy of the chosen image
  /// in Cariño's own storage, or null if nothing was picked.
  static Future<String?> pickImage() =>
      _methods.invokeMethod<String>('pickImage');

  static Future<bool> setSystemWallpaper(String path, String which) async =>
      await _methods.invokeMethod<bool>('setSystemWallpaper', {
        'path': path,
        'which': which,
      }) ??
      false;

  static Future<bool> setSystemWallpaperBytes(
    Uint8List png,
    String which,
  ) async =>
      await _methods.invokeMethod<bool>('setSystemWallpaper', {
        'bytes': png,
        'which': which,
      }) ??
      false;

  static Future<Battery?> battery() async {
    final m = await _methods.invokeMapMethod<String, Object?>('battery');
    if (m == null) return null;
    return Battery(m['level']! as int, (m['charging'] as bool?) ?? false);
  }

  /// Notification counts by package (only apps that allow dots).
  static Future<Map<String, int>> dots() async {
    final m = await _methods.invokeMapMethod<String, int>('dots');
    return m ?? const {};
  }

  static Future<bool> hasNotificationAccess() async =>
      await _methods.invokeMethod<bool>('hasNotificationAccess') ?? false;

  static Future<void> requestNotificationAccess() =>
      _methods.invokeMethod('requestNotificationAccess');

  /// Locks the screen through the accessibility service; false if it
  /// isn't turned on.
  static Future<bool> lockScreen() async =>
      await _methods.invokeMethod<bool>('lockScreen') ?? false;

  static Future<bool> hasLockAccess() async =>
      await _methods.invokeMethod<bool>('hasLockAccess') ?? false;

  static Future<void> requestLockAccess() =>
      _methods.invokeMethod('requestLockAccess');

  /// calendar or contacts.
  static Future<bool> hasPermission(String name) async =>
      await _methods.invokeMethod<bool>('hasPermission', {'name': name}) ??
      false;

  /// Asks Android for calendar or contacts access; true if granted.
  static Future<bool> requestPermission(String name) async =>
      await _methods.invokeMethod<bool>('requestPermission', {'name': name}) ??
      false;

  static Future<CalendarEvent?> nextEvent() async {
    final m = await _methods.invokeMapMethod<String, Object?>('nextEvent');
    if (m == null) return null;
    return CalendarEvent(
      m['title']! as String,
      DateTime.fromMillisecondsSinceEpoch(m['begin']! as int),
      DateTime.fromMillisecondsSinceEpoch(m['end']! as int),
    );
  }

  static Future<List<ContactHit>> searchContacts(String query) async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'searchContacts',
      {'query': query},
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        ContactHit(
          m['id']! as int,
          m['lookup']! as String,
          m['name']! as String,
        ),
    ];
  }

  static Future<void> openContact(ContactHit c) =>
      _methods.invokeMethod('openContact', {'id': c.id, 'lookup': c.lookup});

  /// Opens a system settings screen by its intent action.
  static Future<bool> openSetting(String action) async =>
      await _methods.invokeMethod<bool>('openSetting', {'action': action}) ??
      false;

  /// What's playing, or null (nothing, or no notification access).
  static Future<MediaState?> media() async {
    final m = await _methods.invokeMapMethod<Object?, Object?>('media');
    return m == null ? null : MediaState.fromMap(m);
  }

  /// play, pause, next, previous, or seek (with [position]).
  static Future<void> mediaAction(String action, {Duration? position}) =>
      _methods.invokeMethod('mediaAction', {
        'action': action,
        'position': position?.inMilliseconds,
      });

  /// Opens the app that is playing.
  static Future<void> mediaOpen() => _methods.invokeMethod('mediaOpen');

  /// Today's remaining events (with calendar access) and the next alarm.
  static Future<UpNext> upNext() async {
    final m = await _methods.invokeMapMethod<Object?, Object?>('upNext');
    return m == null ? const UpNext([], null) : UpNext.fromMap(m);
  }

  /// The phone's last known approximate place (needs location access).
  static Future<WeatherPlace?> lastLocation() async {
    final m = await _methods.invokeMapMethod<String, double>('lastLocation');
    if (m == null) return null;
    return WeatherPlace('', m['lat']!, m['lon']!);
  }

  static Future<void> torch(bool on) =>
      _methods.invokeMethod('torch', {'on': on});

  static Future<bool> torchState() async =>
      await _methods.invokeMethod<bool>('torchState') ?? false;

  /// A system quick panel: wifi, internet, bluetooth, volume, nfc, dnd.
  static Future<void> panel(String name) =>
      _methods.invokeMethod('panel', {'name': name});

  /// clock, timer, alarm, calendar, camera, settings, homeSettings.
  static Future<void> open(String name) =>
      _methods.invokeMethod('openIntent', {'name': name});

  /// Opens a web page in the browser.
  static Future<void> openUrl(String url) => webSearch('', url: url);

  static Future<void> webSearch(String query, {String? url}) =>
      _methods.invokeMethod('webSearch', {'query': query, 'url': url});
}
