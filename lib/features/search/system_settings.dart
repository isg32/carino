import '../../core/icons/v_icons.dart';

/// A system settings screen Search can open.
class SystemSetting {
  const SystemSetting(this.label, this.action, this.icon, this.keywords);

  final String label;

  /// The intent action that opens it.
  final String action;
  final VIcon icon;

  /// Other words people type for it.
  final List<String> keywords;

  bool matches(String q) =>
      label.toLowerCase().contains(q) ||
      keywords.any((k) => k.startsWith(q) || q.length > 3 && k.contains(q));
}

const systemSettings = [
  SystemSetting('Wi-Fi', 'android.settings.WIFI_SETTINGS', VIcon.wifi, [
    'wifi',
    'wireless',
    'network',
    'internet',
  ]),
  SystemSetting(
    'Bluetooth',
    'android.settings.BLUETOOTH_SETTINGS',
    VIcon.bluetooth,
    ['bluetooth', 'pair', 'headphones', 'earbuds'],
  ),
  SystemSetting(
    'Network & internet',
    'android.settings.WIRELESS_SETTINGS',
    VIcon.internet,
    ['mobile', 'data', 'sim', 'airplane', 'hotspot'],
  ),
  SystemSetting(
    'Data usage',
    'android.settings.DATA_USAGE_SETTINGS',
    VIcon.internet,
    ['data', 'usage', 'mobile'],
  ),
  SystemSetting('Display', 'android.settings.DISPLAY_SETTINGS', VIcon.image, [
    'brightness',
    'screen',
    'dark',
    'font',
    'timeout',
  ]),
  SystemSetting(
    'Sound & vibration',
    'android.settings.SOUND_SETTINGS',
    VIcon.volume,
    ['sound', 'volume', 'ringtone', 'vibration', 'silent'],
  ),
  SystemSetting(
    'Do not disturb',
    'android.settings.ZEN_MODE_PRIORITY_SETTINGS',
    VIcon.moon,
    ['dnd', 'focus', 'silence', 'disturb'],
  ),
  SystemSetting(
    'Notifications',
    'android.settings.NOTIFICATION_SETTINGS',
    VIcon.bell,
    ['notifications', 'alerts'],
  ),
  SystemSetting(
    'Battery',
    'android.intent.action.POWER_USAGE_SUMMARY',
    VIcon.battery,
    ['battery', 'power', 'saver', 'charging'],
  ),
  SystemSetting('Apps', 'android.settings.APPLICATION_SETTINGS', VIcon.apps, [
    'apps',
    'applications',
    'uninstall',
  ]),
  SystemSetting(
    'Default apps',
    'android.settings.MANAGE_DEFAULT_APPS_SETTINGS',
    VIcon.apps,
    ['default', 'browser', 'home', 'launcher'],
  ),
  SystemSetting(
    'Storage',
    'android.settings.INTERNAL_STORAGE_SETTINGS',
    VIcon.copy,
    ['storage', 'space', 'memory', 'files'],
  ),
  SystemSetting(
    'Location',
    'android.settings.LOCATION_SOURCE_SETTINGS',
    VIcon.globe,
    ['location', 'gps'],
  ),
  SystemSetting('Security', 'android.settings.SECURITY_SETTINGS', VIcon.lock, [
    'security',
    'lock',
    'fingerprint',
    'face',
    'pin',
    'password',
  ]),
  SystemSetting('Privacy', 'android.settings.PRIVACY_SETTINGS', VIcon.hide, [
    'privacy',
    'permissions',
  ]),
  SystemSetting(
    'Accessibility',
    'android.settings.ACCESSIBILITY_SETTINGS',
    VIcon.person,
    ['accessibility', 'talkback'],
  ),
  SystemSetting('Date & time', 'android.settings.DATE_SETTINGS', VIcon.clock, [
    'date',
    'time',
    'timezone',
  ]),
  SystemSetting('Languages', 'android.settings.LOCALE_SETTINGS', VIcon.globe, [
    'language',
    'locale',
    'keyboard',
  ]),
  SystemSetting('NFC', 'android.settings.NFC_SETTINGS', VIcon.wifi, [
    'nfc',
    'tap',
    'pay',
  ]),
  SystemSetting(
    'About phone',
    'android.settings.DEVICE_INFO_SETTINGS',
    VIcon.info,
    ['about', 'phone', 'version', 'build', 'android'],
  ),
  SystemSetting(
    'Developer options',
    'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    VIcon.gear,
    ['developer', 'usb', 'debugging'],
  ),
];

/// Settings screens matching [query], best first.
List<SystemSetting> matchSettings(String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];
  final starts = [
    for (final s in systemSettings)
      if (s.label.toLowerCase().startsWith(q)) s,
  ];
  final rest = [
    for (final s in systemSettings)
      if (!starts.contains(s) && s.matches(q)) s,
  ];
  return [...starts, ...rest].take(3).toList();
}
