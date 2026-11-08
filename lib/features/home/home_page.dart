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
    this.onDoubleTap,
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

  /// Double-tap on Home's empty space.
  final VoidCallback? onDoubleTap;

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
    return _HomeGestures(
      enabled: !editing,
      onSpread: onSpread,
      onSwipeUp: onSwipeUp,
      onSwipeDown: onSwipeDown,
      // Long-press and double-tap live on a layer behind the content, so
      // they only see Home's empty space: icons and the clock take their
      // own taps first, and are never slowed by the double-tap wait.
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: editing ? null : onLongPressEmpty,
            onDoubleTap: editing ? null : onDoubleTap,
          ),
          content,
        ],
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
    final event = preview ? null : ref.watch(nextEventProvider).value;
    final hm = DateFormat(settings.clock24 ? 'HH:mm' : 'h:mm a');
    final weather = preview ? null : ref.watch(weatherProvider).value;
    final glance = <String>[
      if (weather != null)
        '${weather.temperature.round()}° ${weather.condition.toLowerCase()}',
      if (settings.showBattery && battery != null)
        '${battery.level}%${battery.charging ? ' · charging' : ''}',
      if (event != null)
        event.ongoing
            ? 'Now: ${event.title}'
            : '${event.begin.day == now.day ? '' : 'Tomorrow '}'
                  '${hm.format(event.begin)} ${event.title}',
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
            GestureDetector(
              onTap: event == null ? null : () => Launcher.open('calendar'),
              child: Text(
                glance.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VText.inter(
                  13,
                  weight: 300,
                ).copyWith(color: ink.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Home's swipes and the two-finger spread, read from raw pointers as one
/// gesture so they can't be confused:
///
/// - Once a second finger touches down, the gesture is a spread (or
///   nothing) and can never also count as a swipe.
/// - A swipe is one finger only, mostly vertical, far enough and quick.
///
/// Raw pointers never enter the gesture arena, so taps, long-presses and
/// the horizontal page swipe keep working as before.
class _HomeGestures extends StatefulWidget {
  const _HomeGestures({
    required this.child,
    required this.enabled,
    this.onSpread,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onSpread;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  @override
  State<_HomeGestures> createState() => _HomeGesturesState();
}

class _HomeGesturesState extends State<_HomeGestures> {
  final _points = <int, Offset>{};
  final _starts = <int, Offset>{};
  Duration? _downAt;
  double? _spreadStart;
  bool _multi = false;
  bool _done = false;

  double get _distance {
    final p = _points.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    if (_points.isEmpty) {
      _multi = false;
      _done = false;
      _downAt = e.timeStamp;
    }
    _points[e.pointer] = e.position;
    _starts[e.pointer] = e.position;
    if (_points.length >= 2) {
      _multi = true;
      _spreadStart = _points.length == 2 ? _distance : null;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_points.containsKey(e.pointer)) return;
    _points[e.pointer] = e.position;
    final start = _spreadStart;
    if (_done || _points.length != 2 || start == null) return;
    final d = _distance;
    if (d > start * 1.5 && d - start > 120) {
      _done = true;
      HapticFeedback.mediumImpact();
      widget.onSpread?.call();
    }
  }

  void _up(PointerUpEvent e) {
    final start = _starts.remove(e.pointer);
    _points.remove(e.pointer);
    if (_points.length < 2) _spreadStart = null;
    if (_points.isNotEmpty || _done || _multi || start == null) return;
    final delta = e.position - start;
    final ms = (e.timeStamp - (_downAt ?? e.timeStamp)).inMilliseconds;
    final vertical = delta.dy.abs() > delta.dx.abs() * 1.8;
    if (!vertical || delta.dy.abs() < 70 || ms > 700) return;
    _done = true;
    if (delta.dy < 0) {
      widget.onSwipeUp?.call();
    } else {
      widget.onSwipeDown?.call();
    }
  }

  void _cancel(PointerCancelEvent e) {
    _points.remove(e.pointer);
    _starts.remove(e.pointer);
    if (_points.length < 2) _spreadStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? _down : null,
      onPointerMove: widget.enabled ? _move : null,
      onPointerUp: widget.enabled ? _up : null,
      onPointerCancel: widget.enabled ? _cancel : null,
      child: widget.child,
    );
  }
}
