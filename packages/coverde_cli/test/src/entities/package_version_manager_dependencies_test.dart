import 'package:coverde/src/entities/entities.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group('$PackageVersionManagerDependencies', () {
    test('supports value equality', () {
      final logger = _MockLogger();
      final httpClient = _MockHttpClient();
      final subject = PackageVersionManagerDependencies(
        logger: logger,
        httpClient: httpClient,
        globalLockFilePath: 'some/path/to/pubspec.lock',
        baseUrl: 'https://example.com',
        rawDartVersion: '3.6.0',
      );
      final same = PackageVersionManagerDependencies(
        logger: logger,
        httpClient: httpClient,
        globalLockFilePath: 'some/path/to/pubspec.lock',
        baseUrl: 'https://example.com',
        rawDartVersion: '3.6.0',
      );
      final other = PackageVersionManagerDependencies(
        logger: _MockLogger(),
        httpClient: _MockHttpClient(),
        globalLockFilePath: 'some/path/to/other/pubspec.lock',
        baseUrl: 'https://other-example.net',
        rawDartVersion: '3.5.0',
      );
      expect(subject, same);
      expect(subject, isNot(other));
    });

    test('supports hash code comparison', () {
      final subject = PackageVersionManagerDependencies(
        logger: _MockLogger(),
        httpClient: _MockHttpClient(),
        globalLockFilePath: 'some/path/to/pubspec.lock',
        baseUrl: 'https://example.com',
        rawDartVersion: '3.6.0',
      );
      final same = PackageVersionManagerDependencies(
        logger: _MockLogger(),
        httpClient: _MockHttpClient(),
        globalLockFilePath: 'some/path/to/pubspec.lock',
        baseUrl: 'https://example.com',
        rawDartVersion: '3.6.0',
      );
      final other = PackageVersionManagerDependencies(
        logger: _MockLogger(),
        httpClient: _MockHttpClient(),
        globalLockFilePath: 'some/path/to/other/pubspec.lock',
        baseUrl: 'https://other-example.net',
        rawDartVersion: '3.5.0',
      );
      expect(subject.hashCode, same.hashCode);
      expect(subject.hashCode, isNot(other.hashCode));
    });
  });
}
