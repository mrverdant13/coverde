import 'package:args/command_runner.dart';
import 'package:coverde/coverde.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group('coverde', () {
    late Logger logger;
    late http.Client httpClient;

    setUp(() {
      logger = _MockLogger();
      httpClient = _MockHttpClient();
    });

    test('| fails when an invalid sub-command is used', () async {
      Future<void> action() {
        return coverde(
          args: ['invalid'],
          logger: logger,
          globalLockFilePath: '',
          pubApiBaseUrl: '',
          httpClient: httpClient,
          rawDartVersion: '',
        );
      }

      expect(
        action,
        throwsA(isA<UsageException>()),
      );
    });
  });
}
