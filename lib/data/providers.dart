import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/launcher.dart';
import '../platform/widget_host.dart';
import 'models.dart';

/// Set in `main` once preferences are loaded.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider is overridden in main'),
);

// region Apps

/// Every launchable app, A–Z, refreshed when packages change.
/// Every launchable app, A–Z, refreshed when packages change.
///
/// The list is cached: after a reboot Home shows the cached apps at once
/// and refreshes in the background. With no cache (first run), the loading
/// screen shows until Android answers.
class AppsNotifier extends AsyncNotifier<List<AppEntry>> {
  static const _cacheKey = 'apps_cache';
  StreamSubscription<Object?>? _sub;

  @override
  Future<List<AppEntry>> build() async {
    _sub ??= Launcher.events
        .where((e) => e['type'] == 'packages')
        .listen((_) => refresh());
    ref.onDispose(() => _sub?.cancel());
    final cached = _readCache();
    if (cached != null) {
      unawaited(Future.microtask(refresh));
      return cached;
    }
    return _load();
  }

  List<AppEntry>? _readCache() {
    final raw = ref.read(prefsProvider).getString(_cacheKey);
    if (raw == null) return null;
    try {
      final list = [
        for (final m in jsonDecode(raw) as List<Object?>)
          AppEntry.fromMap(m! as Map<Object?, Object?>),
      ];
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  /// Right after boot the package service can answer slowly or with an
  /// empty list; ask again for a little while before giving up.
  Future<List<AppEntry>> _load() async {
    var apps = <AppEntry>[];
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        apps = await Launcher.apps();
      } catch (_) {
        apps = [];
      }
      if (apps.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (apps.isNotEmpty) {
      unawaited(
        ref
            .read(prefsProvider)
            .setString(
              _cacheKey,
              jsonEncode([for (final a in apps) a.toMap()]),
            ),
      );
    }
    return apps;
  }

  Future<void> refresh() async {
    final apps = await _load();
    if (apps.isNotEmpty) state = AsyncData(apps);
  }
}

final appsProvider = AsyncNotifierProvider<AppsNotifier, List<AppEntry>>(
  AppsNotifier.new,
);

/// Apps by key, for Home and the dock.
final appIndexProvider = Provider<Map<String, AppEntry>>((ref) {
  final apps = ref.watch(appsProvider).value ?? const [];
  return {for (final a in apps) a.key: a};
});

/// Apps shown in the Apps tab: everything that isn't hidden.
final visibleAppsProvider = Provider<List<AppEntry>>((ref) {
  final apps = ref.watch(appsProvider).value ?? const [];
  final hidden = ref.watch(settingsProvider.select((s) => s.hidden));
  return [
    for (final a in apps)
      if (!hidden.contains(a.key)) a,
  ];
});

/// Icon PNG for (app key, mono). Kept for the session.
final iconProvider = FutureProvider.family<Uint8List?, (String, bool)>((
  ref,
  arg,
) async {
  try {
    return await Launcher.icon(arg.$1, size: 160, mono: arg.$2);
  } catch (_) {
    return null;
  }
});

// endregion

// region Settings

class SettingsNotifier extends Notifier<CarinoSettings> {
  static const _key = 'settings';

  @override
  CarinoSettings build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const CarinoSettings();
    try {
      return _offerNewWidgets(
        CarinoSettings.fromJson(
          (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
        ),
      );
    } catch (_) {
      return const CarinoSettings();
    }
  }

  /// A built-in widget added in a newer version joins the top of the
  /// Widgets tab once; if it's removed later it isn't offered again.
  CarinoSettings _offerNewWidgets(CarinoSettings s) {
    final fresh = [
      for (final w in BuiltinWidget.values)
        if (!s.knownWidgets.contains(w.name)) w.name,
    ];
    if (fresh.isEmpty) return s;
    // Second, so a new widget is seen without pushing the first one down.
    final at = s.widgets.isEmpty ? 0 : 1;
    return s.copyWith(
      widgets: [...s.widgets.take(at), ...fresh, ...s.widgets.skip(at)],
      knownWidgets: [...s.knownWidgets, ...fresh],
    );
  }

  void update(CarinoSettings Function(CarinoSettings s) change) {
    state = change(state);
    unawaited(
      ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson())),
    );
  }

  void toggleHidden(String key) => update((s) {
    final hidden = {...s.hidden};
    if (!hidden.remove(key)) hidden.add(key);
    return s.copyWith(hidden: hidden);
  });
}

final settingsProvider = NotifierProvider<SettingsNotifier, CarinoSettings>(
  SettingsNotifier.new,
);

// endregion

// region Layouts

class LayoutsState {
  const LayoutsState(this.layouts, this.activeId, {this.seeded = false});

  final List<HomeLayout> layouts;
  final String activeId;

  /// The first layout has been filled with apps.
  final bool seeded;

  HomeLayout get active =>
      layouts.firstWhere((l) => l.id == activeId, orElse: () => layouts.first);

  int get activeIndex {
    final i = layouts.indexWhere((l) => l.id == activeId);
    return i < 0 ? 0 : i;
  }
}

class LayoutsNotifier extends Notifier<LayoutsState> {
  static const _key = 'layouts';

  @override
  LayoutsState build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw != null) {
      try {
        final j = (jsonDecode(raw) as Map<Object?, Object?>)
            .cast<String, Object?>();
        final layouts = [
          for (final l in j['layouts']! as List<Object?>)
            HomeLayout.fromJson(
              (l! as Map<Object?, Object?>).cast<String, Object?>(),
            ),
        ];
        if (layouts.isNotEmpty) {
          return LayoutsState(
            layouts,
            (j['active'] as String?) ?? layouts.first.id,
            seeded: (j['seeded'] as bool?) ?? true,
          );
        }
      } catch (_) {}
    }
    return const LayoutsState([
      HomeLayout(id: 'night', name: 'Night'),
    ], 'night');
  }

  void _save(LayoutsState next) {
    state = next;
    unawaited(
      ref
          .read(prefsProvider)
          .setString(
            _key,
            jsonEncode({
              'layouts': [for (final l in next.layouts) l.toJson()],
              'active': next.activeId,
              'seeded': next.seeded,
            }),
          ),
    );
  }

  /// Fills the first layout with likely favourites and a dock, once.
  void seed(List<AppEntry> apps) {
    if (state.seeded || apps.isEmpty) return;
    String? find(List<String> names) {
      for (final n in names) {
        for (final a in apps) {
          if (a.label.toLowerCase() == n) return a.key;
        }
      }
      return null;
    }

    final dock = [
      find(['phone', 'dialer']),
      find(['messages', 'messaging', 'sms']),
      find(['chrome', 'browser', 'firefox', 'brave', 'internet']),
      find(['camera']),
    ];
    final used = <String>{...dock.whereType<String>()};
    final favs = <String?>[];
    for (final names in [
      ['gmail', 'mail', 'email'],
      ['spotify', 'youtube music', 'music'],
      ['maps', 'google maps'],
      ['calendar'],
      ['photos', 'gallery'],
      ['clock'],
      ['files', 'files by google', 'file manager'],
      ['settings'],
    ]) {
      final k = find(names);
      if (k != null && used.add(k)) favs.add(k);
    }
    final first = state.layouts.first.copyWith(favourites: favs, dock: dock);
    _save(
      LayoutsState(
        [first, ...state.layouts.skip(1)],
        state.activeId,
        seeded: true,
      ),
    );
  }

  void setActive(String id) =>
      _save(LayoutsState(state.layouts, id, seeded: state.seeded));

  void updateLayout(HomeLayout layout) => _save(
    LayoutsState(
      [for (final l in state.layouts) l.id == layout.id ? layout : l],
      state.activeId,
      seeded: state.seeded,
    ),
  );

  void updateActive(HomeLayout Function(HomeLayout l) change) =>
      updateLayout(change(state.active));

  /// Adds a layout (a copy of [from], or blank) and makes it active.
  HomeLayout add({HomeLayout? from}) {
    final id = 'l${DateTime.now().millisecondsSinceEpoch}';
    final layout = from != null
        ? from.copyWith(id: id, name: '${from.name} copy')
        : HomeLayout(
            id: id,
            name: 'Layout ${state.layouts.length + 1}',
            dock: state.active.dock,
          );
    _save(LayoutsState([...state.layouts, layout], id, seeded: state.seeded));
    return layout;
  }

  void delete(String id) {
    if (state.layouts.length < 2) return;
    final rest = [
      for (final l in state.layouts)
        if (l.id != id) l,
    ];
    _save(
      LayoutsState(
        rest,
        state.activeId == id ? rest.first.id : state.activeId,
        seeded: state.seeded,
      ),
    );
  }

  /// Puts [key] in the first empty favourite slot of the active layout.
  bool pinToHome(String key) {
    final l = state.active;
    final grid = l.favGrid;
    if (grid.contains(key) || l.dockRow.contains(key)) return true;
    final i = grid.indexOf(null);
    if (i < 0) return false;
    grid[i] = key;
    updateLayout(l.copyWith(favourites: grid));
    return true;
  }

  void removeFromHome(String key) {
    final l = state.active;
    updateLayout(
      l.copyWith(
        favourites: [for (final k in l.favGrid) k == key ? null : k],
        dock: [for (final k in l.dockRow) k == key ? null : k],
      ),
    );
  }

  void setFavourite(int index, String? key) {
    final grid = state.active.favGrid;
    if (index >= grid.length) return;
    grid[index] = key;
    updateActive((l) => l.copyWith(favourites: grid));
  }

  void setDock(int index, String? key) {
    final row = state.active.dockRow;
    if (index >= row.length) return;
    row[index] = key;
    updateActive((l) => l.copyWith(dock: row));
  }

  /// Swaps two Home slots. Slots are numbered favourites first, then dock.
  void swapSlots(int a, int b) {
    final l = state.active;
    final all = [...l.favGrid, ...l.dockRow];
    if (a >= all.length || b >= all.length) return;
    final t = all[a];
    all[a] = all[b];
    all[b] = t;
    updateLayout(
      l.copyWith(
        favourites: all.sublist(0, l.favSlots),
        dock: all.sublist(l.favSlots),
      ),
    );
  }
}

final layoutsProvider = NotifierProvider<LayoutsNotifier, LayoutsState>(
  LayoutsNotifier.new,
);

final activeLayoutProvider = Provider<HomeLayout>(
  (ref) => ref.watch(layoutsProvider).active,
);

// endregion

// region Device

final batteryProvider = StreamProvider<Battery>((ref) async* {
  final now = await Launcher.battery();
  if (now != null) yield now;
  yield* Launcher.events
      .where((e) => e['type'] == 'battery')
      .map(
        (e) => Battery(e['level']! as int, (e['charging'] as bool?) ?? false),
      );
});

final torchProvider = StreamProvider<bool>((ref) async* {
  yield await Launcher.torchState();
  yield* Launcher.events
      .where((e) => e['type'] == 'torch')
      .map((e) => (e['on'] as bool?) ?? false);
});

final defaultHomeProvider = StreamProvider<bool>((ref) async* {
  yield await Launcher.isDefaultHome();
  yield* Launcher.events
      .where((e) => e['type'] == 'resume')
      .map((e) => (e['defaultHome'] as bool?) ?? false);
});

/// Notification counts by package, for dots. Empty without access.
final dotsProvider = StreamProvider<Map<String, int>>((ref) async* {
  yield await Launcher.dots();
  yield* Launcher.events
      .where((e) => e['type'] == 'dots')
      .map(
        (e) => (e['counts']! as Map<Object?, Object?>).map(
          (k, v) => MapEntry(k! as String, v! as int),
        ),
      );
});

final notificationAccessProvider = StreamProvider<bool>((ref) async* {
  yield await Launcher.hasNotificationAccess();
  yield* Launcher.events
      .where((e) => e['type'] == 'resume')
      .map((e) => (e['notificationAccess'] as bool?) ?? false);
});

final lockAccessProvider = StreamProvider<bool>((ref) async* {
  yield await Launcher.hasLockAccess();
  yield* Launcher.events
      .where((e) => e['type'] == 'resume')
      .map((e) => (e['lockAccess'] as bool?) ?? false);
});

/// What's playing, for the Now playing widget.
final mediaProvider = StreamProvider<MediaState?>((ref) async* {
  yield await Launcher.media();
  yield* Launcher.events.where((e) => e['type'] == 'media').map((e) {
    final m = e['media'] as Map<Object?, Object?>?;
    return m == null ? null : MediaState.fromMap(m);
  });
});

/// Whether calendar or contacts access is granted, checked again whenever
/// Cariño comes back to the front (after the system dialog or Settings).
final permissionProvider = StreamProvider.family<bool, String>((
  ref,
  name,
) async* {
  yield await Launcher.hasPermission(name);
  yield* Launcher.events
      .where((e) => e['type'] == 'resume')
      .asyncMap((_) => Launcher.hasPermission(name));
});

/// Up next, refreshed each minute while Cariño is in front.
final upNextProvider = FutureProvider<UpNext>((ref) async {
  ref.watch(nowProvider);
  try {
    return await Launcher.upNext();
  } catch (_) {
    return const UpNext([], null);
  }
});

/// What a hosted widget is (its app and name), for its label and menu.
final hostedInfoProvider = FutureProvider.family<WidgetProvider?, int>(
  (ref, id) => WidgetHost.info(id),
);

/// The next calendar event, refreshed each minute while Cariño is in front.
final nextEventProvider = FutureProvider<CalendarEvent?>((ref) async {
  if (!ref.watch(settingsProvider.select((s) => s.showNextEvent))) return null;
  ref.watch(nowProvider);
  try {
    return await Launcher.nextEvent();
  } catch (_) {
    return null;
  }
});

/// Whether [app] shows a dot: dots on, and it has notifications.
final dotProvider = Provider.family<bool, String>((ref, package) {
  if (!ref.watch(settingsProvider.select((s) => s.dots))) return false;
  final counts = ref.watch(dotsProvider).value ?? const {};
  return (counts[package] ?? 0) > 0;
});

/// The current minute, for clocks. Ticks once a minute, on the minute, and
/// not at all while Cariño is in the background.
final nowProvider = StreamProvider<DateTime>((ref) {
  final out = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    timer?.cancel();
    final now = DateTime.now();
    out.add(now);
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    timer = Timer(next.difference(now), schedule);
  }

  final lifecycle = AppLifecycleListener(
    onResume: schedule,
    onHide: () => timer?.cancel(),
  );
  schedule();
  ref.onDispose(() {
    timer?.cancel();
    lifecycle.dispose();
    out.close();
  });
  return out.stream;
});

// endregion
