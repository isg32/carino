import 'package:flutter/services.dart';

/// A widget another app offers.
class WidgetProvider {
  const WidgetProvider({
    required this.provider,
    required this.user,
    required this.package,
    required this.label,
    required this.app,
    required this.minWidth,
    required this.minHeight,
    required this.configurable,
  });

  factory WidgetProvider.fromMap(Map<Object?, Object?> m) => WidgetProvider(
    provider: m['provider']! as String,
    user: (m['user']! as num).toInt(),
    package: m['package']! as String,
    label: m['label']! as String,
    app: m['app']! as String,
    minWidth: (m['minWidth']! as num).toInt(),
    minHeight: (m['minHeight']! as num).toInt(),
    configurable: m['configurable']! as bool,
  );

  final String provider;
  final int user;
  final String package;
  final String label;
  final String app;

  /// In dp.
  final int minWidth;
  final int minHeight;
  final bool configurable;

  /// Rows it needs on the Widgets tab (a row is [WidgetHost.rowHeight]).
  int get rows => (minHeight / WidgetHost.rowHeight).ceil().clamp(1, 4);
}

/// Dart side of `CarinoWidgets.kt`: widgets from other apps.
abstract final class WidgetHost {
  static const _methods = MethodChannel('carino/widgets');

  /// Height of one row of a hosted widget, in dp.
  static const double rowHeight = 92;

  static Future<List<WidgetProvider>> providers() async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'providers',
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        WidgetProvider.fromMap(m),
    ];
  }

  static Future<Uint8List?> preview(WidgetProvider p) =>
      _methods.invokeMethod<Uint8List>('preview', {
        'provider': p.provider,
        'user': p.user,
      });

  /// Binds a new widget (Android may ask the user, and the widget's own
  /// setup screen may run). Its id, or null if it was cancelled.
  static Future<int?> add(WidgetProvider p) => _methods.invokeMethod<int>(
    'add',
    {'provider': p.provider, 'user': p.user},
  );

  static Future<WidgetProvider?> info(int id) async {
    final m = await _methods.invokeMapMethod<Object?, Object?>('info', {
      'id': id,
    });
    return m == null ? null : WidgetProvider.fromMap(m);
  }

  static Future<void> configure(int id) =>
      _methods.invokeMethod('configure', {'id': id});

  static Future<void> remove(int id) =>
      _methods.invokeMethod('remove', {'id': id});
}
