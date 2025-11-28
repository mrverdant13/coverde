import 'dart:io';

import 'package:coverde/src/utils/operating_system.dart';
import 'package:test/test.dart';

void main() {
  group('operatingSystem', () {
    test('returns actual OS', () async {
      expect(operatingSystemIdentifier, equals(Platform.operatingSystem));
    });

    test('returns linux', () async {
      debugOperatingSystemIdentifier = 'linux';
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystemIdentifier, equals('linux'));
    });

    test('returns macos', () async {
      debugOperatingSystemIdentifier = 'macos';
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystemIdentifier, equals('macos'));
    });

    test('returns windows', () async {
      debugOperatingSystemIdentifier = 'windows';
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystemIdentifier, equals('windows'));
    });
  });
}
