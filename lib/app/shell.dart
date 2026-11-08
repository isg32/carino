import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/v_palette.dart';
import '../core/widgets/v_buttons.dart';
import '../core/widgets/v_glass.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../features/apps/apps_page.dart';
import '../features/common/dot_loader.dart';
import '../features/common/popup.dart';
import '../features/common/wallpaper.dart';
import '../features/common/wallpaper_sync.dart';
import '../features/customise/customise_screen.dart';
import '../features/home/home_grid.dart';
import '../features/home/home_page.dart';
import '../features/home/home_scene.dart';
import '../features/menus/app_menu.dart';
import '../features/menus/app_picker.dart';
import '../features/search/search_sheet.dart';
import '../features/settings/settings_page.dart';
import '../features/vault/vault.dart';
import '../features/widgets/widgets_page.dart';
import '../platform/launcher.dart';
import 'tabs.dart';

/// Cariño's one screen: Home, Apps and Widgets side by side under the
/// pill, the dock below it, and Customise behind them all, reached by
/// zooming Home out into its own card.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => ShellState();
}

class ShellState extends ConsumerState<Shell> with TickerProviderStateMixin {
  final _pages = PageController();

  /// 0 = Home at full size, 1 = Home sitting in its Customise card.
  late final _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  bool _editing = false;
  StreamSubscription<Map<Object?, Object?>>? _events;

  @override
  void initState() {
    super.initState();
    _events = Launcher.events.listen((e) {
      if (e['type'] == 'home') goHome();
    });
    // Fill the first layout once the apps are known.
    ref.read(appsProvider.future).then((apps) {
      if (mounted) ref.read(layoutsProvider.notifier).seed(apps);
    }, onError: (Object _) {});
    // Keep Android's own wallpaper (seen in Recents and behind app
    // transitions) the same as the active layout's.
    ref.listenManual(
      activeLayoutProvider,
      (_, _) => _scheduleWallpaperSync(),
      fireImmediately: true,
    );
  }

  Timer? _wallpaperTimer;
  bool _syncing = false;

  void _scheduleWallpaperSync() {
    _wallpaperTimer?.cancel();
    // In Customise you may flick through layouts; set it once on the way out.
    if (_zoom.value > 0) return;
    _wallpaperTimer = Timer(const Duration(milliseconds: 900), _syncWallpaper);
  }

  /// Sets the system home wallpaper to the active layout's, in the
  /// background: Cariño already shows the new wallpaper itself, so nothing
  /// waits on this. Only when what shows has changed (it is slow, and it
  /// recolours Material You).
  Future<void> _syncWallpaper() async {
    if (!mounted || _syncing) return;
    final layout = ref.read(activeLayoutProvider);
    // A blurred copy needs no detail: a quarter of the screen is plenty,
    // and Android scales it up for far less work than a full-size image.
    final size = View.of(context).physicalSize / 4;
    final prefs = ref.read(prefsProvider);
    final signature = wallpaperSignature(layout, size);
    if (prefs.getString('system_wallpaper') == signature) return;
    _syncing = true;
    try {
      final png = await renderWallpaperPng(layout, size, soft: true);
      if (png != null && await Launcher.setSystemWallpaperBytes(png, 'home')) {
        await prefs.setString('system_wallpaper', signature);
      }
    } catch (_) {
      // Leave the system wallpaper as it is; the next change tries again.
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _wallpaperTimer?.cancel();
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? (_pages.page ?? 0)
      : 0;

  /// Home button: close whatever is open and come back to Home.
  void goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (_zoom.value > 0) _zoom.reverse();
    if (_editing) setState(() => _editing = false);
    if (_pages.hasClients && _page != 0) {
      _pages.animateToPage(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void goTo(int index) {
    _pages.animateToPage(
      index,
      duration: VTabBar.duration,
      curve: VTabBar.curve,
    );
  }

  void _onBack() {
    if (_zoom.value > 0) {
      _zoom.reverse();
    } else if (_editing) {
      setState(() => _editing = false);
    } else if (_page != 0) {
      goTo(0);
    }
  }

  void openCustomise() {
    if (_editing) return;
    HapticFeedback.mediumImpact();
    _zoom.forward();
  }

  void closeCustomise() => _zoom.reverse().whenComplete(_scheduleWallpaperSync);

  void openSearch() =>
      showBlurPopup(context, (_) => const SearchSheet(), sheet: true);

  void _gesture(GestureAction a) {
    switch (a) {
      case GestureAction.search:
        openSearch();
      case GestureAction.notifications:
        Launcher.expandNotifications();
      case GestureAction.customise:
        openCustomise();
      case GestureAction.apps:
        goTo(1);
      case GestureAction.nothing:
        break;
    }
  }

  void setEditing(bool value) {
    HapticFeedback.mediumImpact();
    setState(() => _editing = value);
    if (value && _page != 0) goTo(0);
  }

  void _menu(BuildContext context, AppEntry app, Rect rect) {
    showAppMenu(
      context,
      app: app,
      iconRect: rect,
      onEditHome: () => setEditing(true),
    );
  }

  Future<void> _pickForSlot(int slot) async {
    final app = await pickApp(context);
    if (app == null) return;
    final layouts = ref.read(layoutsProvider.notifier);
    final l = ref.read(activeLayoutProvider);
    if (slot < l.favSlots) {
      layouts.setFavourite(slot, app.key);
    } else {
      layouts.setDock(slot - l.favSlots, app.key);
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push(CupertinoPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(activeLayoutProvider);
    final settings = ref.watch(settingsProvider);

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final m = HomeMetrics(padding.bottom);
    final card = CustomiseGeometry.cardRect(size, padding);

    final scene = LayoutTheme(
      layout: layout,
      child: _scene(layout, settings, m),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: AnimatedBuilder(
        animation: _zoom,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_zoom.value);
          final zooming = _zoom.value > 0;
          final settled = _zoom.value >= 1;
          final scale = lerpDouble(1, card.width / size.width, t)!;
          // A blur rides the motion and is gone at either end.
          final motionBlur = math.sin(math.pi * t) * 5;
          return Stack(
            children: [
              if (zooming)
                Positioned.fill(
                  child: CustomiseScreen(
                    progress: _zoom,
                    onDone: closeCustomise,
                    onSettings: _openSettings,
                  ),
                ),
              Offstage(
                offstage: settled,
                child: IgnorePointer(
                  ignoring: zooming,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..translateByDouble(card.left * t, card.top * t, 0, 1)
                      ..scaleByDouble(scale, scale, 1, 1),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        lerpDouble(0, 22 / scale, t)!,
                      ),
                      child: ImageFiltered(
                        enabled: motionBlur > 0.05,
                        imageFilter: ImageFilter.blur(
                          sigmaX: motionBlur,
                          sigmaY: motionBlur,
                        ),
                        child: SizedBox.fromSize(size: size, child: scene),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: BusyOverlay(
                  busy: wallpaperBusy,
                  label: 'Setting wallpaper',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scene(HomeLayout layout, CarinoSettings settings, HomeMetrics m) {
    final palette = VPalette.of(context);
    // Only the veil, the edge blur and the pill follow the swipe frame by
    // frame; the pages, wallpaper and dock are built once and repainted on
    // their own.
    double away() => _page.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: WallpaperView(
            wallpaper: layout.wallpaper,
            dim: layout.dim,
            blur: layout.blur,
          ),
        ),
        // Apps and Widgets sit on a soft copy of the wallpaper under a veil.
        // It fades in with the swipe, so there is no seam between tabs. The
        // soft copy is the wallpaper decoded tiny and scaled up: it looks
        // blurred but costs nothing per frame, unlike a live blur.
        AnimatedBuilder(
          animation: _pages,
          builder: (context, child) {
            final a = away();
            return Opacity(opacity: a, child: a == 0 ? null : child);
          },
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                WallpaperView(
                  wallpaper: layout.wallpaper,
                  dim: layout.dim,
                  soft: true,
                ),
                ColoredBox(color: palette.veil),
              ],
            ),
          ),
        ),
        RepaintBoundary(
          child: PageView(
            controller: _pages,
            physics: _editing
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            children: [
              HomePage(
                layout: layout,
                editing: _editing,
                bottomClearance: m.clearance,
                onLongPressEmpty: openCustomise,
                onSwipeUp: () => _gesture(settings.swipeUp),
                onSwipeDown: () => _gesture(settings.swipeDown),
                onMenu: _menu,
                onPickEmpty: _pickForSlot,
                onSpread: () => openHiddenApps(context, ref),
              ),
              AppsPage(bottomClearance: m.clearance, onMenu: _menu),
              WidgetsPage(bottomClearance: m.clearance),
            ],
          ),
        ),
        // Top and bottom edges blur on every tab: content softens under
        // the status bar, and behind the pill and the dock.
        const Positioned(left: 0, right: 0, top: 0, child: VStatusBarBlur()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VEdgeBlur(
            edge: VEdge.bottom,
            solid: m.clearance - 30,
            fade: 60,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: m.pillBottom,
          child: _editing
              ? Center(
                  child: SizedBox(
                    width: 160,
                    child: VButton.primary(
                      'Done',
                      onPressed: () => setEditing(false),
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) {
                    final page = _page;
                    return VTabBar(
                      items: carinoTabs,
                      index: page.round(),
                      position: page,
                      onTap: goTo,
                    );
                  },
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: m.dockBottom,
          child: RepaintBoundary(
            child: HomeRow(
              keys: layout.dockRow,
              firstSlot: layout.favSlots,
              layout: layout,
              editing: _editing,
              labels: false,
              onMenu: _menu,
              onPickEmpty: _pickForSlot,
            ),
          ),
        ),
      ],
    );
  }
}
