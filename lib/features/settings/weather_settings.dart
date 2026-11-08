import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_controls.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_page.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/providers.dart';
import '../../data/weather.dart';
import '../../platform/launcher.dart';
import '../common/dot_loader.dart';
import '../common/popup.dart';

/// Settings › Weather: off until turned on, because it is the one thing in
/// Cariño that uses the network.
class WeatherSettingsPage extends ConsumerWidget {
  const WeatherSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final weather = ref.watch(weatherProvider).value;

    Future<void> turnOn(bool on) async {
      if (!on) {
        n.update((s) => s.copyWith(weatherOn: false));
        return;
      }
      final ok = await confirmDialog(
        context,
        title: 'Turn on weather?',
        body:
            'Cariño will ask Open-Meteo for the weather: only the place’s '
            'coordinates are sent, at most every 30 minutes, and only while '
            'Cariño is on screen. No account, no key, nothing else.',
        action: 'Turn on',
      );
      if (!ok) return;
      n.update((s) => s.copyWith(weatherOn: true));
      if (s.weatherPlace == null && context.mounted) {
        await showPlacePicker(context, ref);
      }
    }

    final place = s.weatherPlace;
    return VDetailPage(
      backLabel: 'Settings',
      title: 'Weather',
      children: [
        VListSection(
          children: [
            VListRow(
              title: 'Weather',
              subtitle: 'On Home and in the Weather widget',
              trailing: VSwitch(value: s.weatherOn, onChanged: turnOn),
            ),
            if (s.weatherOn) ...[
              VListRow(
                title: 'Place',
                value: place == null
                    ? 'Here (approximate)'
                    : place.name.split(',').first,
                onTap: () => showPlacePicker(context, ref),
              ),
              VListRow(
                title: 'Units',
                trailing: VSegmented<bool>(
                  compact: true,
                  segments: const {false: '°C', true: '°F'},
                  value: s.weatherFahrenheit,
                  onChanged: (v) =>
                      n.update((s) => s.copyWith(weatherFahrenheit: v)),
                ),
              ),
            ],
          ],
        ),
        if (s.weatherOn && weather != null)
          VCard(
            child: Row(
              children: [
                Text(
                  '${weather.temperature.round()}°',
                  style: VText.doto(40, weight: 800, height: 1),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${weather.condition}\nH ${weather.high.round()}° L ${weather.low.round()}°',
                    style: VText.inter(14, weight: 300, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        const VFootnote(
          'Weather comes from Open-Meteo (open-meteo.com). This is the only '
          'thing Cariño fetches from the internet.',
        ),
      ],
    );
  }
}

/// Choose where the weather is for: here, or a city you search for.
Future<void> showPlacePicker(BuildContext context, WidgetRef ref) =>
    showBlurPopup<void>(context, (_) => const _PlacePicker(), sheet: true);

class _PlacePicker extends ConsumerStatefulWidget {
  const _PlacePicker();

  @override
  ConsumerState<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<_PlacePicker> {
  Timer? _debounce;
  List<WeatherPlace> _results = const [];
  bool _searching = false;
  int _query = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final id = ++_query;
      setState(() => _searching = true);
      List<WeatherPlace> found;
      try {
        found = await WeatherService.search(text);
      } catch (_) {
        found = const [];
      }
      if (mounted && id == _query) {
        setState(() {
          _results = found;
          _searching = false;
        });
      }
    });
  }

  void _choose(WeatherPlace? place) {
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(weatherPlace: () => place));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    return CarinoSheet(
      title: 'Weather for',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VListSection(
            children: [
              VListRow(
                title: 'Here',
                subtitle: 'The phone’s last known place, roughly. Never GPS.',
                leading: const VIconView(VIcon.globe, size: 18),
                onTap: () async {
                  if (await Launcher.requestPermission('location')) {
                    _choose(null);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          VOutlined(
            radius: 22,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const VIconView(VIcon.search, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoTextField(
                      padding: EdgeInsets.zero,
                      decoration: null,
                      cursorColor: ink,
                      placeholder: 'Or search for a city',
                      placeholderStyle: VText.inter(
                        14,
                        weight: 300,
                      ).copyWith(color: ink.withValues(alpha: 0.7)),
                      style: VText.inter(14).copyWith(color: ink),
                      onChanged: _changed,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: DotLoader(size: 8)),
            )
          else if (_results.isNotEmpty)
            VListSection(
              children: [
                for (final p in _results)
                  VListRow(title: p.name, onTap: () => _choose(p)),
              ],
            ),
        ],
      ),
    );
  }
}
