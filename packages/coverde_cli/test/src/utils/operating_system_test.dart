import 'dart:io';

import 'package:coverde/src/utils/operating_system.dart';
import 'package:test/test.dart';

void main() {
  group('operatingSystem', () {
    test('returns actual OS', () async {
      expect(operatingSystem.identifier, equals(Platform.operatingSystem));
    });

    test('returns linux', () async {
      debugOperatingSystemIdentifier = OperatingSystem.linux.identifier;
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystem, equals(OperatingSystem.linux));
    });

    test('returns macos', () async {
      debugOperatingSystemIdentifier = OperatingSystem.macos.identifier;
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystem, equals(OperatingSystem.macos));
    });

    test('returns windows', () async {
      debugOperatingSystemIdentifier = OperatingSystem.windows.identifier;
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(operatingSystem, equals(OperatingSystem.windows));
    });

    test(
        'throws $UnsupportedError '
        'when unsupported operating system', () async {
      debugOperatingSystemIdentifier = 'unsupported';
      addTearDown(() => debugOperatingSystemIdentifier = null);
      expect(() => operatingSystem, throwsA(isA<UnsupportedError>()));
    });
  });
}
