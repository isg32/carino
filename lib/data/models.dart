/// An app Cariño can launch: one launcher activity in one profile.
class AppEntry {
  const AppEntry({
    required this.key,
    required this.package,
    required this.label,
    required this.installedAt,
    this.work = false,
    this.paused = false,
  });

  factory AppEntry.fromMap(Map<Object?, Object?> m) => AppEntry(
    key: m['key']! as String,
    package: m['package']! as String,
    label: m['label']! as String,
    installedAt: DateTime.fromMillisecondsSinceEpoch(
      (m['installed'] as int?) ?? 0,
    ),
    work: (m['work'] as bool?) ?? false,
    paused: (m['paused'] as bool?) ?? false,
  );

  /// `package/activity#userSerial`; stable across launches.
  final String key;
  final String package;
  final String label;
  final DateTime installedAt;

  /// In the work profile.
  final bool work;

  /// Work profile paused.
  final bool paused;

  /// The A–Z section it belongs to; `#` for digits and symbols.
  String get section {
    if (label.isEmpty) return '#';
    final c = label[0].toUpperCase();
    return RegExp('[A-Z]').hasMatch(c) ? c : '#';
  }

  bool get isNew =>
      DateTime.now().difference(installedAt) < const Duration(days: 2);

  Map<String, Object?> toMap() => {
    'key': key,
    'package': package,
    'label': label,
    'installed': installedAt.millisecondsSinceEpoch,
    'work': work,
    'paused': paused,
  };
}

/// One of an app's own shortcuts (Launcher3's deep shortcuts).
class AppShortcut {
  const AppShortcut(this.id, this.label);

  final String id;
  final String label;
}

enum InkMode { white, black, auto }

enum IconStyle { mono, colored }

/// What a layout shows behind Home: a built-in palette or a photo.
class WallpaperRef {
  const WallpaperRef.builtin(String this.builtin) : photo = null;
  const WallpaperRef.photo(String this.photo) : builtin = null;

  factory WallpaperRef.fromJson(Map<String, Object?> j) => j['photo'] != null
      ? WallpaperRef.photo(j['photo']! as String)
      : WallpaperRef.builtin((j['builtin'] as String?) ?? 'night');

  final String? builtin;
  final String? photo;

  Map<String, Object?> toJson() => {'builtin': builtin, 'photo': photo};

  @override
  bool operator ==(Object other) =>
      other is WallpaperRef && other.builtin == builtin && other.photo == photo;

  @override
  int get hashCode => Object.hash(builtin, photo);
}

/// One saved home screen: its wallpaper, ink, glass, icons and apps.
class HomeLayout {
  const HomeLayout({
    required this.id,
    required this.name,
    this.wallpaper = const WallpaperRef.builtin('night'),
    this.dim = 0.0,
    this.blur = 0.0,
    this.ink = InkMode.white,
    this.glass = 0.5,
    this.icons = IconStyle.mono,
    this.columns = 4,
    this.favRows = 2,
    this.favourites = const [],
    this.dock = const [],
  });

  factory HomeLayout.fromJson(Map<String, Object?> j) => HomeLayout(
    id: j['id']! as String,
    name: j['name']! as String,
    wallpaper: WallpaperRef.fromJson(
      (j['wallpaper'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
          const {},
    ),
    dim: ((j['dim'] as num?) ?? 0).toDouble(),
    blur: ((j['blur'] as num?) ?? 0).toDouble(),
    ink: InkMode.values.byName((j['ink'] as String?) ?? 'white'),
    glass: ((j['glass'] as num?) ?? 0.5).toDouble(),
    icons: IconStyle.values.byName((j['icons'] as String?) ?? 'mono'),
    columns: (j['columns'] as int?) ?? 4,
    favRows: (j['favRows'] as int?) ?? 2,
    favourites: [
      for (final k in (j['favourites'] as List<Object?>?) ?? const [])
        k as String?,
    ],
    dock: [
      for (final k in (j['dock'] as List<Object?>?) ?? const []) k as String?,
    ],
  );

  final String id;
  final String name;
  final WallpaperRef wallpaper;

  /// Darkening over the wallpaper, 0–0.6, so ink stays readable.
  final double dim;

  /// Blur over a photo wallpaper, 0–1. Rendered once to a file.
  final double blur;
  final InkMode ink;
  final double glass;
  final IconStyle icons;

  /// Dock size, and the favourites grid's column count (they match).
  final int columns;
  final int favRows;

  /// App keys, row by row; null is an empty slot.
  final List<String?> favourites;
  final List<String?> dock;

  int get favSlots => columns * favRows;

  /// [favourites] padded or cut to exactly [favSlots].
  List<String?> get favGrid => [
    for (var i = 0; i < favSlots; i++)
      i < favourites.length ? favourites[i] : null,
  ];

  /// [dock] padded or cut to exactly [columns].
  List<String?> get dockRow => [
    for (var i = 0; i < columns; i++) i < dock.length ? dock[i] : null,
  ];

  HomeLayout copyWith({
    String? id,
    String? name,
    WallpaperRef? wallpaper,
    double? dim,
    double? blur,
    InkMode? ink,
    double? glass,
    IconStyle? icons,
    int? columns,
    int? favRows,
    List<String?>? favourites,
    List<String?>? dock,
  }) => HomeLayout(
    id: id ?? this.id,
    name: name ?? this.name,
    wallpaper: wallpaper ?? this.wallpaper,
    dim: dim ?? this.dim,
    blur: blur ?? this.blur,
    ink: ink ?? this.ink,
    glass: glass ?? this.glass,
    icons: icons ?? this.icons,
    columns: columns ?? this.columns,
    favRows: favRows ?? this.favRows,
    favourites: favourites ?? this.favourites,
    dock: dock ?? this.dock,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'wallpaper': wallpaper.toJson(),
    'dim': dim,
    'blur': blur,
    'ink': ink.name,
    'glass': glass,
    'icons': icons.name,
    'columns': columns,
    'favRows': favRows,
    'favourites': favourites,
    'dock': dock,
  };
}

enum AppsView { list, grid }

enum SearchMode { apps, essentials }

enum GestureAction { search, notifications, customise, apps, nothing }

/// The built-in widgets on the Widgets tab.
enum BuiltinWidget { clock, battery, calendar, notes }

/// Everything in Settings, plus the Widgets tab's contents and Essentials.
class CarinoSettings {
  const CarinoSettings({
    this.onboarded = false,
    this.appsView = AppsView.list,
    this.newBadges = true,
    this.scrubberHaptics = true,
    this.searchWeb = true,
    this.webEngine = 'DuckDuckGo',
    this.searchOpensOn = SearchMode.apps,
    this.enterLaunches = true,
    this.haptics = true,
    this.clock24 = true,
    this.showBattery = true,
    this.showDate = true,
    this.swipeUp = GestureAction.search,
    this.swipeDown = GestureAction.notifications,
    this.hidden = const {},
    this.hiddenFindByName = false,
    this.essentials = const [
      'wifi',
      'bluetooth',
      'torch',
      'dnd',
      'timer',
      'alarm',
      'camera',
    ],
    this.widgets = const [
      BuiltinWidget.clock,
      BuiltinWidget.battery,
      BuiltinWidget.calendar,
      BuiltinWidget.notes,
    ],
    this.note = '',
    this.photos = const [],
  });

  factory CarinoSettings.fromJson(Map<String, Object?> j) {
    T e<T extends Enum>(List<T> values, Object? v, T fallback) {
      for (final x in values) {
        if (x.name == v) return x;
      }
      return fallback;
    }

    const d = CarinoSettings();
    return CarinoSettings(
      onboarded: (j['onboarded'] as bool?) ?? d.onboarded,
      appsView: e(AppsView.values, j['appsView'], d.appsView),
      newBadges: (j['newBadges'] as bool?) ?? d.newBadges,
      scrubberHaptics: (j['scrubberHaptics'] as bool?) ?? d.scrubberHaptics,
      searchWeb: (j['searchWeb'] as bool?) ?? d.searchWeb,
      webEngine: (j['webEngine'] as String?) ?? d.webEngine,
      searchOpensOn: e(SearchMode.values, j['searchOpensOn'], d.searchOpensOn),
      enterLaunches: (j['enterLaunches'] as bool?) ?? d.enterLaunches,
      haptics: (j['haptics'] as bool?) ?? d.haptics,
      clock24: (j['clock24'] as bool?) ?? d.clock24,
      showBattery: (j['showBattery'] as bool?) ?? d.showBattery,
      showDate: (j['showDate'] as bool?) ?? d.showDate,
      swipeUp: e(GestureAction.values, j['swipeUp'], d.swipeUp),
      swipeDown: e(GestureAction.values, j['swipeDown'], d.swipeDown),
      hidden: {
        for (final k in (j['hidden'] as List<Object?>?) ?? const [])
          k! as String,
      },
      hiddenFindByName: (j['hiddenFindByName'] as bool?) ?? d.hiddenFindByName,
      essentials: [
        for (final k in (j['essentials'] as List<Object?>?) ?? d.essentials)
          k! as String,
      ],
      widgets: [
        for (final k
            in (j['widgets'] as List<Object?>?) ??
                [for (final w in d.widgets) w.name])
          e(BuiltinWidget.values, k, BuiltinWidget.clock),
      ],
      note: (j['note'] as String?) ?? '',
      photos: [
        for (final p in (j['photos'] as List<Object?>?) ?? const [])
          p! as String,
      ],
    );
  }

  final bool onboarded;
  final AppsView appsView;
  final bool newBadges;
  final bool scrubberHaptics;
  final bool searchWeb;
  final String webEngine;
  final SearchMode searchOpensOn;
  final bool enterLaunches;
  final bool haptics;
  final bool clock24;
  final bool showBattery;
  final bool showDate;
  final GestureAction swipeUp;
  final GestureAction swipeDown;
  final Set<String> hidden;
  final bool hiddenFindByName;
  final List<String> essentials;
  final List<BuiltinWidget> widgets;

  /// The Notes widget's text.
  final String note;

  /// Photos picked as wallpapers, kept for the Wallpaper sheet.
  final List<String> photos;

  CarinoSettings copyWith({
    bool? onboarded,
    AppsView? appsView,
    bool? newBadges,
    bool? scrubberHaptics,
    bool? searchWeb,
    String? webEngine,
    SearchMode? searchOpensOn,
    bool? enterLaunches,
    bool? haptics,
    bool? clock24,
    bool? showBattery,
    bool? showDate,
    GestureAction? swipeUp,
    GestureAction? swipeDown,
    Set<String>? hidden,
    bool? hiddenFindByName,
    List<String>? essentials,
    List<BuiltinWidget>? widgets,
    String? note,
    List<String>? photos,
  }) => CarinoSettings(
    onboarded: onboarded ?? this.onboarded,
    appsView: appsView ?? this.appsView,
    newBadges: newBadges ?? this.newBadges,
    scrubberHaptics: scrubberHaptics ?? this.scrubberHaptics,
    searchWeb: searchWeb ?? this.searchWeb,
    webEngine: webEngine ?? this.webEngine,
    searchOpensOn: searchOpensOn ?? this.searchOpensOn,
    enterLaunches: enterLaunches ?? this.enterLaunches,
    haptics: haptics ?? this.haptics,
    clock24: clock24 ?? this.clock24,
    showBattery: showBattery ?? this.showBattery,
    showDate: showDate ?? this.showDate,
    swipeUp: swipeUp ?? this.swipeUp,
    swipeDown: swipeDown ?? this.swipeDown,
    hidden: hidden ?? this.hidden,
    hiddenFindByName: hiddenFindByName ?? this.hiddenFindByName,
    essentials: essentials ?? this.essentials,
    widgets: widgets ?? this.widgets,
    note: note ?? this.note,
    photos: photos ?? this.photos,
  );

  Map<String, Object?> toJson() => {
    'onboarded': onboarded,
    'appsView': appsView.name,
    'newBadges': newBadges,
    'scrubberHaptics': scrubberHaptics,
    'searchWeb': searchWeb,
    'webEngine': webEngine,
    'searchOpensOn': searchOpensOn.name,
    'enterLaunches': enterLaunches,
    'haptics': haptics,
    'clock24': clock24,
    'showBattery': showBattery,
    'showDate': showDate,
    'swipeUp': swipeUp.name,
    'swipeDown': swipeDown.name,
    'hidden': hidden.toList(),
    'hiddenFindByName': hiddenFindByName,
    'essentials': essentials,
    'widgets': [for (final w in widgets) w.name],
    'note': note,
    'photos': photos,
  };
}

/// Battery level (0–100) and whether it is charging.
class Battery {
  const Battery(this.level, this.charging);

  final int level;
  final bool charging;
}
