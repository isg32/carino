import 'dart:convert';
import 'dart:io';

/// A place weather is shown for.
class WeatherPlace {
  const WeatherPlace(this.name, this.lat, this.lon);

  factory WeatherPlace.fromJson(Map<String, Object?> j) => WeatherPlace(
    j['name']! as String,
    (j['lat']! as num).toDouble(),
    (j['lon']! as num).toDouble(),
  );

  /// Empty for "here" (the phone's last known place).
  final String name;
  final double lat;
  final double lon;

  Map<String, Object?> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  @override
  bool operator ==(Object other) =>
      other is WeatherPlace &&
      other.name == name &&
      other.lat == lat &&
      other.lon == lon;

  @override
  int get hashCode => Object.hash(name, lat, lon);
}

/// The weather now and today's high and low.
class Weather {
  const Weather({
    required this.temperature,
    required this.code,
    required this.high,
    required this.low,
    required this.at,
  });

  factory Weather.fromJson(Map<String, Object?> j) => Weather(
    temperature: (j['temperature']! as num).toDouble(),
    code: (j['code']! as num).toInt(),
    high: (j['high']! as num).toDouble(),
    low: (j['low']! as num).toDouble(),
    at: DateTime.parse(j['at']! as String),
  );

  /// In the unit it was asked for.
  final double temperature;

  /// WMO weather code.
  final int code;
  final double high;
  final double low;
  final DateTime at;

  String get condition => describeWeather(code);

  Map<String, Object?> toJson() => {
    'temperature': temperature,
    'code': code,
    'high': high,
    'low': low,
    'at': at.toIso8601String(),
  };
}

/// WMO codes in a word or two.
String describeWeather(int code) => switch (code) {
  0 => 'Clear',
  1 => 'Mostly clear',
  2 => 'Partly cloudy',
  3 => 'Cloudy',
  45 || 48 => 'Fog',
  51 || 53 || 55 || 56 || 57 => 'Drizzle',
  61 || 63 || 66 => 'Rain',
  65 || 67 => 'Heavy rain',
  71 || 73 || 75 || 77 => 'Snow',
  80 || 81 || 82 => 'Showers',
  85 || 86 => 'Snow showers',
  95 || 96 || 99 => 'Thunderstorm',
  _ => 'Weather',
};

/// Open-Meteo: free, no account, no key. Only coordinates (or the city you
/// typed) are sent.
abstract final class WeatherService {
  static final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'Carino launcher';

  static Future<Map<String, Object?>> _get(Uri uri) async {
    final request = await _client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final body = await response.transform(utf8.decoder).join();
    return (jsonDecode(body) as Map<Object?, Object?>).cast<String, Object?>();
  }

  static Future<Weather> fetch(
    WeatherPlace place, {
    required bool fahrenheit,
  }) async {
    final j = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': place.lat.toStringAsFixed(2),
        'longitude': place.lon.toStringAsFixed(2),
        'current': 'temperature_2m,weather_code',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': '1',
        'timezone': 'auto',
        if (fahrenheit) 'temperature_unit': 'fahrenheit',
      }),
    );
    final current = (j['current']! as Map<Object?, Object?>);
    final daily = (j['daily']! as Map<Object?, Object?>);
    return Weather(
      temperature: (current['temperature_2m']! as num).toDouble(),
      code: (current['weather_code']! as num).toInt(),
      high: ((daily['temperature_2m_max']! as List<Object?>).first! as num)
          .toDouble(),
      low: ((daily['temperature_2m_min']! as List<Object?>).first! as num)
          .toDouble(),
      at: DateTime.now(),
    );
  }

  /// Cities matching [name], for the place search.
  static Future<List<WeatherPlace>> search(String name) async {
    if (name.trim().length < 2) return const [];
    final j = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name.trim(),
        'count': '6',
      }),
    );
    return [
      for (final r in (j['results'] as List<Object?>?) ?? const [])
        () {
          final m = (r! as Map<Object?, Object?>).cast<String, Object?>();
          final label = [
            m['name'],
            if (m['admin1'] != null) m['admin1'],
            if (m['country'] != null) m['country'],
          ].join(', ');
          return WeatherPlace(
            label,
            (m['latitude']! as num).toDouble(),
            (m['longitude']! as num).toDouble(),
          );
        }(),
    ];
  }
}
