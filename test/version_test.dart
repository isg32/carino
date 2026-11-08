import 'dart:io';

import 'package:carino/features/settings/about_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// The version shown in About must be the one in pubspec.yaml.
void main() {
  test('About shows the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(carinoVersion, match!.group(1));
  });
}
