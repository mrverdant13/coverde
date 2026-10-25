import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$FileCoverageSourceReader', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('coverde_source_reader_test_');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('returns the lines of a source file', () {
      final source = File('${root.path}/app.dart')..writeAsStringSync('a\nb\n');

      final lines = const FileCoverageSourceReader().readLines(source.path);

      expect(lines, ['a', 'b']);
    });

    test('returns null when the source file is missing', () {
      final lines = const FileCoverageSourceReader().readLines(
        '${root.path}/missing.dart',
      );

      expect(lines, isNull);
    });

    test('fails when the source file cannot be read', () {
      final file = _MockFile();
      when(file.existsSync).thenReturn(true);
      when(file.readAsLinesSync).thenThrow(const FileSystemException('denied'));
      final reader = FileCoverageSourceReader(open: (_) => file);

      expect(
        () => reader.readLines('lib/a.dart'),
        throwsA(
          isA<CoverageReportSourceReadFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            'Failed to read source file at `lib/a.dart`.\ndenied',
          ),
        ),
      );
    });
  });

  group('$CoverageReportRequest', () {
    test('keeps variables as an unmodifiable string map', () async {
      final document = CoverageDocument.parse('');
      final sink = StringBuffer();
      final request = CoverageReportRequest(
        document: document,
        sources: const FileCoverageSourceReader(),
        destination: ConsoleReportDestination(sink),
        variables: const {'min-line-rate': '80'},
      );
      final reporter = _RecordingReporter();

      await reporter.render(request);

      expect(reporter.request, same(request));
      expect(request.variables, {'min-line-rate': '80'});
      expect(() => request.variables['other'] = '1', throwsUnsupportedError);
      expect(request.destination, isA<ConsoleReportDestination>());
    });
  });

  group('$CoverageReportSourceReadFailure', () {
    test('readableMessage names the path and the file-system error', () {
      final failure = CoverageReportSourceReadFailure.fromFileSystemException(
        path: 'lib/a.dart',
        exception: const FileSystemException('denied'),
      );

      expect(
        failure.readableMessage,
        'Failed to read source file at `lib/a.dart`.\ndenied',
      );
    });
  });

  group('$CoverageReportDestinationFailure', () {
    test('readableMessage names the path and the file-system error', () {
      final failure = CoverageReportDestinationFailure.fromFileSystemException(
        path: 'coverage/index.html',
        exception: const FileSystemException(
          'denied',
          'coverage/index.html',
          OSError('busy', 1),
        ),
      );

      expect(
        failure.readableMessage,
        'Failed to write report file at `coverage/index.html`.\n'
        'denied\n'
        'busy',
      );
    });
  });
}

final class _MockFile extends Mock implements File {}

final class _RecordingReporter implements CoverageReporter {
  CoverageReportRequest? request;

  @override
  Future<void> render(CoverageReportRequest request) async {
    this.request = request;
  }
}
