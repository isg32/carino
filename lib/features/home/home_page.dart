import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import 'home_grid.dart';

/// The Home tab: Doto clock and date, a glance line, the favourites grid
/// (the dock's columns) and the swipe-up hint. The pill and dock are drawn
/// by the shell, below this.
class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.layout,
    required this.editing,
    required this.bottomClearance,
    this.onLongPressEmpty,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onMenu,
    this.onPickEmpty,
    this.onSpread,
    this.preview = false,
  });

  final HomeLayout layout;
  final bool editing;

  /// Room left at the bottom for the pill and the dock.
  final double bottomClearance;
  final VoidCallback? onLongPressEmpty;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final SlotMenu? onMenu;
  final void Function(int slot)? onPickEmpty;

  /// Two fingers spread apart on Home (the hidden apps).
  final VoidCallback? onSpread;

  /// Drawn in a Customise card: no gestures, frozen clock.
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final grid = layout.favGrid;
    final content = Padding(
      padding: EdgeInsets.only(top: top + 40, bottom: bottomClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: editing ? 0.45 : 1,
            child: _ClockHeader(preview: preview),
          ),
          const Spacer(),
          if (editing)
            Center(
              child: Text(
                'Drag to move · tap + to add',
                style: VText.inter(13, weight: 500),
              ),
            ),
          if (editing) const SizedBox(height: 28),
          for (var r = 0; r < layout.favRows; r++) ...[
            if (r > 0) const SizedBox(height: 22),
            HomeRow(
              keys: grid.sublist(r * layout.columns, (r + 1) * layout.columns),
              firstSlot: r * layout.columns,
              layout: layout,
              editing: editing,
              labels: true,
              onMenu: onMenu,
              onPickEmpty: onPickEmpty,
            ),
          ],
          const SizedBox(height: 26),
          Opacity(
            opacity: editing ? 0 : 1,
            child: const Column(
              children: [
                VIconView(VIcon.swipeUp, size: 18),
                SizedBox(height: 2),
                _Hint(),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
    if (preview) return content;
    return _SpreadDetector(
      onSpread: editing ? null : onSpread,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: editing ? null : onLongPressEmpty,
        onVerticalDragEnd: editing
            ? null
            : (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -250) onSwipeUp?.call();
                if (v > 250) onSwipeDown?.call();
              },
        child: content,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) =>
      Text('SEARCH', style: VText.inter(10, weight: 500, letterSpacing: 1.1));
}

class _ClockHeader extends ConsumerWidget {
  const _ClockHeader({required this.preview});

  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final now = preview
        ? DateTime.now()
        : (ref.watch(nowProvider).value ?? DateTime.now());
    final battery = ref.watch(batteryProvider).value;
    final time = DateFormat(settings.clock24 ? 'HH:mm' : 'h:mm').format(now);
    final glance = <String>[
      if (settings.showBattery && battery != null)
        '${battery.level}%${battery.charging ? ' · charging' : ''}',
    ];
    final ink = VInk.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settings.showDate)
            GestureDetector(
              onTap: () => Launcher.open('calendar'),
              child: Text(
                DateFormat('EEEE d MMMM').format(now).toUpperCase(),
                style: VText.eyebrow,
              ),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Launcher.open('clock');
            },
            child: Text(
              time,
              style: VText.doto(
                108,
                weight: 800,
                height: 0.95,
                letterSpacing: -2,
              ),
            ),
          ),
          if (glance.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              glance.join(' · '),
              style: VText.inter(
                13,
                weight: 300,
              ).copyWith(color: ink.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two fingers moving apart. Listens to raw pointers, so it never competes
/// with the swipes, taps and long-presses on Home.
class _SpreadDetector extends StatefulWidget {
  const _SpreadDetector({required this.child, this.onSpread});

  final Widget child;
  final VoidCallback? onSpread;

  @override
  State<_SpreadDetector> createState() => _SpreadDetectorState();
}

class _SpreadDetectorState extends State<_SpreadDetector> {
  final _points = <int, Offset>{};
  double? _start;
  bool _fired = false;

  double get _distance {
    final p = _points.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _points[e.pointer] = e.position;
    if (_points.length == 2) {
      _start = _distance;
      _fired = false;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_points.containsKey(e.pointer)) return;
    _points[e.pointer] = e.position;
    final start = _start;
    if (_points.length != 2 || start == null || _fired) return;
    final d = _distance;
    if (d > start * 1.5 && d - start > 120) {
      _fired = true;
      HapticFeedback.mediumImpact();
      widget.onSpread?.call();
    }
  }

  void _up(PointerEvent e) {
    _points.remove(e.pointer);
    if (_points.length < 2) _start = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onSpread == null) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
