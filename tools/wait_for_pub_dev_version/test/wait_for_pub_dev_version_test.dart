import 'dart:io';

import 'package:test/test.dart';

import '../wait_for_pub_dev_version.dart';

void main() {
  group('versionListedInPubDevResponse', () {
    late String coverdeFixture;

    setUp(() {
      coverdeFixture = File(
        'test/fixtures/coverde_api.json',
      ).readAsStringSync();
    });

    test('returns true when the version is listed', () {
      expect(
        versionListedInPubDevResponse(coverdeFixture, '0.4.1'),
        isTrue,
      );
    });

    test('returns false when the version is absent', () {
      expect(
        versionListedInPubDevResponse(coverdeFixture, '9.9.9'),
        isFalse,
      );
    });

    test('returns false when versions is missing', () {
      expect(
        versionListedInPubDevResponse('{"name":"coverde"}', '0.4.1'),
        isFalse,
      );
    });

    test('returns false for invalid JSON', () {
      expect(
        versionListedInPubDevResponse('not-json', '0.4.1'),
        isFalse,
      );
    });
  });

  group('waitForPubDevVersion', () {
    test('returns 0 when the version is found on the first attempt', () async {
      final exitCode = await waitForPubDevVersion(
        packageName: 'coverde',
        version: '0.4.1',
        timeout: const Duration(seconds: 1),
        interval: const Duration(milliseconds: 10),
        fetchPackage: (_) async => File(
          'test/fixtures/coverde_api.json',
        ).readAsStringSync(),
      );

      expect(exitCode, 0);
    });

    test('returns 1 when the version is never listed before timeout', () async {
      var now = DateTime.utc(2026, 1, 1, 12);

      final exitCode = await waitForPubDevVersion(
        packageName: 'coverde',
        version: '9.9.9',
        timeout: const Duration(seconds: 1),
        interval: const Duration(milliseconds: 200),
        now: () => now,
        sleep: (_) async {
          now = now.add(const Duration(milliseconds: 500));
        },
        fetchPackage: (_) async => File(
          'test/fixtures/coverde_api.json',
        ).readAsStringSync(),
      );

      expect(exitCode, 1);
    });

    test('returns 1 immediately when the package is missing on pub.dev',
        () async {
      final exitCode = await waitForPubDevVersion(
        packageName: 'coverde',
        version: '0.4.1',
        timeout: const Duration(seconds: 5),
        interval: const Duration(milliseconds: 10),
        fetchPackage: (_) async => throw PubDevPackageNotFoundException(
          'Package not found on pub.dev: coverde',
        ),
      );

      expect(exitCode, 1);
    });

    test('returns 1 when fetch returns invalid JSON before timeout', () async {
      var now = DateTime.utc(2026, 1, 1, 12);

      final exitCode = await waitForPubDevVersion(
        packageName: 'coverde',
        version: '0.4.1',
        timeout: const Duration(seconds: 1),
        interval: const Duration(milliseconds: 200),
        now: () => now,
        sleep: (_) async {
          now = now.add(const Duration(milliseconds: 500));
        },
        fetchPackage: (_) async => 'not-json',
      );

      expect(exitCode, 1);
    });

    test('returns 1 when fetch fails after retries', () async {
      final exitCode = await waitForPubDevVersion(
        packageName: 'coverde',
        version: '0.4.1',
        timeout: const Duration(seconds: 5),
        interval: const Duration(milliseconds: 10),
        fetchPackage: (_) async => throw PubDevFetchException(
          'pub.dev API returned HTTP 503 for coverde after 3 attempts.',
        ),
      );

      expect(exitCode, 1);
    });
  });
}
