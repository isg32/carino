import 'package:flutter/widgets.dart';

import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_glass.dart';
import '../../core/widgets/v_ink.dart';
import '../../data/models.dart';
import '../common/wallpaper.dart';
import 'home_grid.dart';
import 'home_page.dart';
import '../../app/tabs.dart';

/// The palette a layout asks for: its ink (auto follows the wallpaper) and
/// its glass strength.
VPalette paletteFor(HomeLayout layout) {
  final light = switch (layout.ink) {
    InkMode.white => false,
    InkMode.black => true,
    InkMode.auto => wallpaperIsLight(layout.wallpaper) && layout.dim < 0.3,
  };
  return (light ? VPalette.light : VPalette.dark).withGlass(layout.glass);
}

/// Applies a layout's ink and glass to everything below.
class LayoutTheme extends StatelessWidget {
  const LayoutTheme({super.key, required this.layout, required this.child});

  final HomeLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(layout);
    return VPaletteScope(
      palette: palette,
      child: DefaultTextStyle.merge(
        style: VText.body.copyWith(color: palette.ink),
        child: child,
      ),
    );
  }
}

/// Where the pill, the dock and Home's content sit, from the bottom inset.
class HomeMetrics {
  HomeMetrics(this.bottomInset);

  final double bottomInset;

  double get dockBottom => bottomInset + 18;
  double get pillBottom => dockBottom + homeIconSize + 18;
  double get pillHeight => 62;

  /// Room Home's own content leaves for the pill and dock.
  double get clearance => pillBottom + pillHeight + 18;
}

/// A whole home screen for a layout, frozen: wallpaper, clock, favourites,
/// the pill on Home and the dock. Used for the Customise cards and the zoom
/// between Home and Customise.
class HomeScene extends StatelessWidget {
  const HomeScene({super.key, required this.layout});

  final HomeLayout layout;

  @override
  Widget build(BuildContext context) {
    final m = HomeMetrics(MediaQuery.paddingOf(context).bottom);
    return LayoutTheme(
      layout: layout,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            WallpaperView(
              wallpaper: layout.wallpaper,
              dim: layout.dim,
              blur: layout.blur,
            ),
            HomePage(
              layout: layout,
              editing: false,
              preview: true,
              bottomClearance: m.clearance,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: m.pillBottom,
              child: VTabBar(items: carinoTabs, index: 0, onTap: (_) {}),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: m.dockBottom,
              child: Builder(
                builder: (context) => DefaultTextStyle.merge(
                  style: TextStyle(color: VInk.of(context)),
                  child: HomeRow(
                    keys: layout.dockRow,
                    firstSlot: layout.favSlots,
                    layout: layout,
                    editing: false,
                    labels: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
