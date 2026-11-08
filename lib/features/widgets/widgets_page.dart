import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../platform/launcher.dart';
import '../../platform/widget_host.dart';
import '../common/dot_loader.dart';
import '../settings/weather_settings.dart';
import '../common/popup.dart';

/// The Widgets tab: Cariño's own widgets, in the order you set.
class WidgetsPage extends ConsumerWidget {
  const WidgetsPage({super.key, required this.bottomClearance});

  final double bottomClearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(settingsProvider.select((s) => s.widgets));
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 24, 16, bottomClearance + 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widgets.length} ${widgets.length == 1 ? 'WIDGET' : 'WIDGETS'}',
                      style: VText.eyebrow,
                    ),
                    const SizedBox(height: 6),
                    Text('Widgets', style: VText.title),
                  ],
                ),
              ),
              VPill(
                'Add',
                fill: VFill.outline,
                leading: const VIconView(
                  VIcon.plus,
                  size: 14,
                  strokeWidth: 1.8,
                ),
                onTap: () => showAddWidget(context),
              ),
            ],
          ),
        ),
        if (widgets.isEmpty)
          VCard(
            outline: VOutline.dashed,
            onTap: () => showAddWidget(context),
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Add your first widget',
                  style: VText.inter(15, weight: 500),
                ),
              ),
            ),
          ),
        for (var i = 0; i < widgets.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _Framed(widgetKey: widgets[i], index: i),
        ],
      ],
    );
  }
}

/// A widget card; long-press for its menu. Cariño's own widgets sit on
/// glass; widgets from other apps keep their own look inside a dashed frame
/// with the app's name above.
class _Framed extends ConsumerWidget {
  const _Framed({required this.widgetKey, required this.index});

  final String widgetKey;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void menu() {
      HapticFeedback.mediumImpact();
      showBlurPopup<void>(
        context,
        (_) => _WidgetMenu(index: index),
        sheet: true,
      );
    }

    final hostedId = WidgetKey.hostedId(widgetKey);
    if (hostedId != null) {
      final rows = ref.watch(
        settingsProvider.select((s) => s.widgetRows[widgetKey] ?? 2),
      );
      return HostedWidget(
        key: ValueKey(widgetKey),
        id: hostedId,
        rows: rows,
        onLongPress: menu,
      );
    }
    final builtin = WidgetKey.builtin(widgetKey);
    if (builtin == null) return const SizedBox.shrink();
    return GestureDetector(
      onLongPress: menu,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VPalette.of(context).glassCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VInk.of(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (builtin) {
            BuiltinWidget.media => const MediaWidget(),
            BuiltinWidget.upNext => const UpNextWidget(),
            BuiltinWidget.clock => const ClockWidget(),
            BuiltinWidget.weather => const WeatherWidget(),
            BuiltinWidget.battery => const BatteryWidget(),
            BuiltinWidget.calendar => const CalendarWidget(),
            BuiltinWidget.notes => const NotesWidget(),
          },
        ),
      ),
    );
  }
}

/// A widget from another app: the app's name, then the widget itself (a
/// native view) in a dashed frame. Taps reach the widget, and so do vertical
/// swipes when it has a list of its own to scroll; otherwise swipes scroll
/// the Widgets tab. A long-press opens Cariño's menu for it.
class HostedWidget extends ConsumerStatefulWidget {
  const HostedWidget({
    super.key,
    required this.id,
    required this.rows,
    required this.onLongPress,
  });

  final int id;
  final int rows;
  final VoidCallback onLongPress;

  @override
  ConsumerState<HostedWidget> createState() => _HostedWidgetState();
}

class _HostedWidgetState extends ConsumerState<HostedWidget> {
  bool _scrolls = false;

  /// Asks once the widget has drawn its content (a moment after creation).
  Future<void> _check() async {
    for (final wait in const [600, 1500]) {
      await Future<void>.delayed(Duration(milliseconds: wait));
      if (!mounted) return;
      if (await WidgetHost.scrollable(widget.id)) {
        if (mounted) setState(() => _scrolls = true);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(hostedInfoProvider(widget.id)).value;
    final height = widget.rows * WidgetHost.rowHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            (info?.heading ?? 'Widget').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VText.eyebrow,
          ),
        ),
        GestureDetector(
          onLongPress: widget.onLongPress,
          child: VOutlined(
            radius: 24,
            outline: VOutline.dashed,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    height: height,
                    child: AndroidView(
                      key: ValueKey('aw-${widget.id}-${widget.rows}'),
                      viewType: 'carino/appwidget',
                      creationParams: {
                        'id': widget.id,
                        'width': box.maxWidth,
                        'height': height,
                      },
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (_) => _check(),
                      gestureRecognizers: {
                        const Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
                        if (_scrolls)
                          const Factory<VerticalDragGestureRecognizer>(
                            VerticalDragGestureRecognizer.new,
                          ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String widgetName(BuiltinWidget w) => switch (w) {
  BuiltinWidget.media => 'Now playing',
  BuiltinWidget.upNext => 'Up next',
  BuiltinWidget.clock => 'Clock',
  BuiltinWidget.weather => 'Weather',
  BuiltinWidget.battery => 'Battery',
  BuiltinWidget.calendar => 'Calendar',
  BuiltinWidget.notes => 'Notes',
};

/// Now playing: whatever any app is playing, with its progress, pause and
/// next. Reads the active media session, which needs notification access.
class MediaWidget extends ConsumerStatefulWidget {
  const MediaWidget({super.key});

  @override
  ConsumerState<MediaWidget> createState() => _MediaWidgetState();
}

class _MediaWidgetState extends ConsumerState<MediaWidget> {
  Timer? _tick;
  double? _seeking;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The elapsed time only moves while something is playing.
  void _ticking(bool on) {
    if (on && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on) {
      _tick?.cancel();
      _tick = null;
    }
  }

  String _time(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(notificationAccessProvider).value ?? false;
    final media = ref.watch(mediaProvider).value;
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);
    _ticking(media?.playing ?? false);

    if (!access || media == null) {
      return Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ink),
            ),
            child: const VIconView(VIcon.music, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOW PLAYING', style: VText.eyebrow),
                const SizedBox(height: 4),
                Text(
                  access ? 'Nothing' : 'See what’s playing in any app',
                  style: VText.inter(14, weight: 300),
                ),
              ],
            ),
          ),
          if (!access)
            const VPill(
              'Allow',
              fill: VFill.outline,
              onTap: Launcher.requestNotificationAccess,
            ),
        ],
      );
    }

    final now = DateTime.now();
    final position = media.positionAt(now);
    final total = media.duration;
    final progress =
        _seeking ??
        (total > Duration.zero
            ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0);
    final subtitle = [
      if (media.artist.isNotEmpty) media.artist,
      if (media.app.isNotEmpty) media.app,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: Launcher.mediaOpen,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ink),
                ),
                child: const VIconView(VIcon.music, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VText.rowTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VText.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _time(position),
                style: VText.doto(20, weight: 800, height: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => IgnorePointer(
                  ignoring: !media.canSeek || total == Duration.zero,
                  child: CarinoSlider(
                    width: box.maxWidth,
                    value: progress,
                    onChanged: (v) {
                      setState(() => _seeking = v);
                      // Seek once the finger settles.
                      _seekTimer?.cancel();
                      _seekTimer = Timer(const Duration(milliseconds: 250), () {
                        Launcher.mediaAction('seek', position: total * v);
                        if (mounted) setState(() => _seeking = null);
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: media.playing ? 'Pause' : 'Play',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Launcher.mediaAction(media.playing ? 'pause' : 'play');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                  child: VIconView(
                    media.playing ? VIcon.pause : VIcon.play,
                    size: 16,
                    strokeWidth: 2.25,
                    color: paper,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Next',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Launcher.mediaAction('next');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink),
                  ),
                  child: const VIconView(VIcon.next, size: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Timer? _seekTimer;
}

/// Up next: what's left of today in the calendar, and the next alarm.
class UpNextWidget extends ConsumerWidget {
  const UpNextWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final up = ref.watch(upNextProvider).value;
    final calendar = ref.watch(permissionProvider('calendar')).value ?? true;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final hm = DateFormat(h24 ? 'HH:mm' : 'h:mm');
    final now = DateTime.now();

    String length(Duration d) {
      if (d.inMinutes < 60) return '${d.inMinutes} min';
      final m = d.inMinutes % 60;
      return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
    }

    final rows = <Widget>[];
    final alarm = up?.alarm;
    if (alarm != null && alarm.difference(now) < const Duration(hours: 24)) {
      rows.add(
        _UpNextRow(
          time: hm.format(alarm),
          title: 'Alarm',
          subtitle: alarm.day == now.day ? 'Today' : 'Tomorrow',
          onTap: () => Launcher.open('clock'),
        ),
      );
    }
    for (final e in up?.events ?? const <UpNextEvent>[]) {
      final ongoing = !e.allDay && now.isAfter(e.begin);
      rows.add(
        _UpNextRow(
          time: e.allDay ? 'DAY' : (ongoing ? 'NOW' : hm.format(e.begin)),
          title: e.title.isEmpty ? 'Event' : e.title,
          subtitle: e.location.isNotEmpty
              ? e.location
              : (e.allDay ? 'All day' : length(e.end.difference(e.begin))),
          onTap: () => Launcher.open('calendar'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('UP NEXT', style: VText.eyebrow)),
            if (!calendar)
              VPill(
                'Allow calendar',
                fill: VFill.outline,
                onTap: () => Launcher.requestPermission('calendar').then((_) {
                  ref.invalidate(permissionProvider('calendar'));
                  ref.invalidate(upNextProvider);
                }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Nothing else today',
              style: VText.inter(14, weight: 300),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const VDivider(),
            rows[i],
          ],
      ],
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String time;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VTappable(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(time, style: VText.doto(18, weight: 800, height: 1)),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VText.rowTitle,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VText.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClockWidget extends ConsumerWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return GestureDetector(
      onTap: () => Launcher.open('clock'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CLOCK', style: VText.eyebrow),
                const SizedBox(height: 10),
                Text(
                  DateFormat(h24 ? 'HH:mm' : 'h:mm').format(now),
                  style: VText.doto(56, weight: 800, height: 1),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('EEE d').format(now).toUpperCase(),
            style: VText.eyebrow,
          ),
        ],
      ),
    );
  }
}

/// Weather now and today's high and low. Off until turned on in Settings,
/// since it is the one thing in Cariño that uses the network.
class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final weather = ref.watch(weatherProvider).value;
    void open() => Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const WeatherSettingsPage()),
    );

    if (!settings.weatherOn || weather == null) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEATHER', style: VText.eyebrow),
                const SizedBox(height: 4),
                Text(
                  settings.weatherOn ? 'Waiting for the weather' : 'Off',
                  style: VText.inter(14, weight: 300),
                ),
              ],
            ),
          ),
          VPill(
            settings.weatherOn ? 'Place' : 'Turn on',
            fill: VFill.outline,
            onTap: open,
          ),
        ],
      );
    }
    final place = settings.weatherPlace?.name.split(',').first;
    return GestureDetector(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place == null ? 'WEATHER' : place.toUpperCase(),
                  style: VText.eyebrow,
                ),
              ),
              const VIconView(VIcon.cloud, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${weather.temperature.round()}°',
            style: VText.doto(46, weight: 800, height: 1),
          ),
          const SizedBox(height: 10),
          Text(
            '${weather.condition} · H ${weather.high.round()}° L ${weather.low.round()}°',
            style: VText.secondary,
          ),
        ],
      ),
    );
  }
}

class BatteryWidget extends ConsumerWidget {
  const BatteryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(batteryProvider).value;
    final level = b?.level ?? 0;
    final ink = VInk.of(context);
    final cells = (level / 10).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('BATTERY', style: VText.eyebrow)),
            if (b?.charging ?? false) Text('Charging', style: VText.secondary),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          b == null ? '—' : '$level%',
          style: VText.doto(46, weight: 800, height: 1),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 10; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < cells ? ink : null,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ink),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday first
    final ink = VInk.of(context);
    final paper = VInk.surfaceOf(context);
    final cells = <int?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return GestureDetector(
      onTap: () => Launcher.open('calendar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(now).toUpperCase(),
            style: VText.eyebrow,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d, style: VText.inter(11, weight: 500)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < cells.length ~/ 7; w++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  for (final d in cells.sublist(w * 7, w * 7 + 7))
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: d == now.day
                              ? BoxDecoration(
                                  color: ink,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            d?.toString() ?? '',
                            style: VText.doto(
                              15,
                              weight: 700,
                            ).copyWith(color: d == now.day ? paper : ink),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class NotesWidget extends ConsumerStatefulWidget {
  const NotesWidget({super.key});

  @override
  ConsumerState<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends ConsumerState<NotesWidget> {
  late final _text = TextEditingController(
    text: ref.read(settingsProvider).note,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOTES', style: VText.eyebrow),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: _text,
          maxLines: 6,
          minLines: 3,
          padding: EdgeInsets.zero,
          placeholder: 'Write something to keep on hand',
          placeholderStyle: VText.inter(
            15,
            weight: 300,
          ).copyWith(color: ink.withValues(alpha: 0.6)),
          style: VText.inter(15, height: 1.5).copyWith(color: ink),
          cursorColor: ink,
          decoration: null,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(note: v)),
        ),
      ],
    );
  }
}

/// Long-press a widget: size and configure (for widgets from other apps),
/// move it, or remove it.
class _WidgetMenu extends ConsumerWidget {
  const _WidgetMenu({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final widgets = settings.widgets;
    if (index >= widgets.length) return const SizedBox.shrink();
    final key = widgets[index];
    final hostedId = WidgetKey.hostedId(key);
    final builtin = WidgetKey.builtin(key);
    final info = hostedId == null
        ? null
        : ref.watch(hostedInfoProvider(hostedId)).value;
    final n = ref.read(settingsProvider.notifier);
    void move(int by) {
      final list = [...widgets];
      final to = (index + by).clamp(0, list.length - 1);
      list.insert(to, list.removeAt(index));
      n.update((s) => s.copyWith(widgets: list));
      Navigator.of(context).pop();
    }

    return CarinoSheet(
      eyebrow: info == null || info.namedAfterApp ? 'Widget' : info.app,
      title: builtin != null ? widgetName(builtin) : (info?.label ?? 'Widget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VListSection(
            children: [
              if (hostedId != null)
                VListRow(
                  title: 'Size',
                  trailing: VSegmented<int>(
                    compact: true,
                    segments: const {1: 'S', 2: 'M', 3: 'L', 4: 'XL'},
                    value: settings.widgetRows[key] ?? info?.rows ?? 2,
                    onChanged: (v) => n.update(
                      (s) => s.copyWith(widgetRows: {...s.widgetRows, key: v}),
                    ),
                  ),
                ),
              if (hostedId != null && (info?.configurable ?? false))
                VListRow(
                  title: 'Configure',
                  leading: const VIconView(VIcon.gear, size: 18),
                  chevron: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    WidgetHost.configure(hostedId);
                  },
                ),
              if (index > 0)
                VListRow(
                  title: 'Move up',
                  leading: const VIconView(VIcon.up, size: 18),
                  chevron: false,
                  onTap: () => move(-1),
                ),
              if (index < widgets.length - 1)
                VListRow(
                  title: 'Move down',
                  leading: const VIconView(VIcon.downArrow, size: 18),
                  chevron: false,
                  onTap: () => move(1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          VButton.primary(
            'Remove widget',
            onPressed: () {
              n.update(
                (s) => s.copyWith(
                  widgets: [...widgets]..removeAt(index),
                  widgetRows: {...s.widgetRows}..remove(key),
                ),
              );
              if (hostedId != null) WidgetHost.remove(hostedId);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// Widgets › Add: Cariño's own widgets, then every app's widgets.
Future<void> showAddWidget(BuildContext context) =>
    showBlurPopup<void>(context, (_) => const _AddWidget(), sheet: true);

class _AddWidget extends ConsumerStatefulWidget {
  const _AddWidget();

  @override
  ConsumerState<_AddWidget> createState() => _AddWidgetState();
}

class _AddWidgetState extends ConsumerState<_AddWidget> {
  late final Future<List<WidgetProvider>> _providers = WidgetHost.providers();
  String? _open;
  bool _adding = false;

  Future<void> _addHosted(WidgetProvider p) async {
    if (_adding) return;
    setState(() => _adding = true);
    final id = await WidgetHost.add(p);
    if (!mounted) return;
    setState(() => _adding = false);
    if (id == null) return;
    final key = WidgetKey.hosted(id);
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            widgets: [...s.widgets, key],
            widgetRows: {...s.widgetRows, key: p.rows},
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final have = ref.watch(settingsProvider.select((s) => s.widgets));
    final missing = [
      for (final w in BuiltinWidget.values)
        if (!have.contains(w.name)) w,
    ];
    return CarinoSheet(
      title: 'Add widget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VEyebrow('Cariño'),
          const SizedBox(height: 10),
          if (missing.isEmpty)
            const VFootnote(
              'Every Cariño widget is already on the Widgets tab.',
            )
          else
            VListSection(
              children: [
                for (final w in missing)
                  VListRow(
                    title: widgetName(w),
                    leading: VIconView(switch (w) {
                      BuiltinWidget.media => VIcon.music,
                      BuiltinWidget.upNext => VIcon.calendar,
                      BuiltinWidget.clock => VIcon.clock,
                      BuiltinWidget.weather => VIcon.cloud,
                      BuiltinWidget.battery => VIcon.battery,
                      BuiltinWidget.calendar => VIcon.calendar,
                      BuiltinWidget.notes => VIcon.edit,
                    }, size: 18),
                    trailing: const VIconView(VIcon.plus, size: 18),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .update(
                            (s) => s.copyWith(widgets: [...s.widgets, w.name]),
                          );
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          const SizedBox(height: 20),
          const VEyebrow('From your apps'),
          const SizedBox(height: 10),
          FutureBuilder<List<WidgetProvider>>(
            future: _providers,
            builder: (context, snap) {
              final all = snap.data;
              if (all == null) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: DotLoader()),
                );
              }
              if (all.isEmpty) {
                return const VFootnote('No app on this phone offers widgets.');
              }
              final byApp = <String, List<WidgetProvider>>{};
              for (final p in all) {
                (byApp[p.app] ??= []).add(p);
              }
              return VListSection(
                children: [
                  for (final e in byApp.entries) ...[
                    VListRow(
                      title: e.key,
                      value:
                          '${e.value.length} ${e.value.length == 1 ? 'widget' : 'widgets'}',
                      chevron: false,
                      trailing: VIconView(
                        _open == e.key ? VIcon.swipeUp : VIcon.down,
                        size: 16,
                      ),
                      onTap: () =>
                          setState(() => _open = _open == e.key ? null : e.key),
                    ),
                    if (_open == e.key)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final p in e.value)
                              _ProviderTile(
                                provider: p,
                                onTap: () => _addHosted(p),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One of an app's widgets: its preview and name, in a dashed frame.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});

  final WidgetProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: VOutlined(
          radius: 16,
          outline: VOutline.dashed,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 84,
                  child: FutureBuilder<Uint8List?>(
                    future: WidgetHost.preview(provider),
                    builder: (context, snap) => snap.data == null
                        ? const SizedBox.shrink()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              snap.data!,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  provider.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VText.inter(12, weight: 500),
                ),
                Text(
                  '${provider.minWidth}×${provider.minHeight} dp',
                  style: VText.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
