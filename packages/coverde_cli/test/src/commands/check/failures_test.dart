import 'package:coverde/src/commands/check/failures.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeCheckFailure', () {
    group('$CoverdeCheckMoreThanOneArgumentFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with usage',
        () {
          const failure = CoverdeCheckMoreThanOneArgumentFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Only one argument (minimum coverage threshold) is expected.

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          const failure = CoverdeCheckMoreThanOneArgumentFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Only one argument (minimum coverage threshold) is expected.',
          );
        },
      );
    });

    group('$CoverdeCheckMissingMinimumCoverageThresholdFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with usage',
        () {
          const failure = CoverdeCheckMissingMinimumCoverageThresholdFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Missing minimum coverage threshold.

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          const failure = CoverdeCheckMissingMinimumCoverageThresholdFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.invalidInputDescription;

          expect(result, 'Missing minimum coverage threshold.');
        },
      );
    });

    group('$CoverdeCheckInvalidMinimumCoverageThresholdFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with usage',
        () {
          const failure = CoverdeCheckInvalidMinimumCoverageThresholdFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid minimum coverage threshold.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          const failure = CoverdeCheckInvalidMinimumCoverageThresholdFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Invalid minimum coverage threshold.\n'
            'It should be a positive number not greater than 100 '
            '[0.0, 100.0].',
          );
        },
      );
    });

    group('$CoverdeCheckTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeCheckTraceFileNotFoundFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(result, 'No trace file found at `/path/to/trace.lcov.info`.');
        },
      );

      test(
        'traceFilePath '
        '| returns the trace file path',
        () {
          const failure = CoverdeCheckTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeCheckEmptyTraceFileFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeCheckEmptyTraceFileFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(
            result,
            'No coverage data found in the trace file located at '
            '`/path/to/trace.lcov.info`.',
          );
        },
      );

      test(
        'traceFilePath '
        '| returns the trace file path',
        () {
          const failure = CoverdeCheckEmptyTraceFileFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeCheckTraceFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path and error message',
        () {
          const exception = FileSystemException(
            'Permission denied',
            '/path/to/trace.lcov.info',
          );
          final failure =
              CoverdeCheckTraceFileReadFailure.fromFileSystemException(
            traceFilePath: '/path/to/trace.lcov.info',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read trace file at `/path/to/trace.lcov.info`.\n'
            'Permission denied',
          );
        },
      );
    });

    group('$CoverdeCheckCoverageBelowMinimumFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with coverage values',
        () {
          final traceFile = TraceFile.parse('''
SF:path/to/file.dart
DA:1,1
DA:2,0
end_of_record
''');
          final failure = CoverdeCheckCoverageBelowMinimumFailure(
            minimumCoverage: 75,
            traceFile: traceFile,
          );

          final result = failure.readableMessage;

          expect(
            result,
            contains('The minimum coverage value has not been reached.'),
          );
          expect(result, contains('Expected min coverage: 75.00 %.'));
          expect(result, contains('Actual coverage:'));
        },
      );

      test(
        'minimumCoverage '
        '| returns the minimum coverage threshold',
        () {
          final traceFile = TraceFile.parse('''
SF:path/to/file.dart
DA:1,1
end_of_record
''');
          final failure = CoverdeCheckCoverageBelowMinimumFailure(
            minimumCoverage: 80.5,
            traceFile: traceFile,
          );

          final result = failure.minimumCoverage;

          expect(result, 80.5);
        },
      );

      test(
        'actualCoverage '
        '| returns the actual coverage from trace file',
        () {
          final traceFile = TraceFile.parse('''
SF:path/to/file.dart
DA:1,1
DA:2,0
end_of_record
''');
          final failure = CoverdeCheckCoverageBelowMinimumFailure(
            minimumCoverage: 75,
            traceFile: traceFile,
          );

          final result = failure.actualCoverage;

          expect(result, traceFile.coverage);
        },
      );

      test(
        'traceFile '
        '| returns the trace file',
        () {
          final traceFile = TraceFile.parse('''
SF:path/to/file.dart
DA:1,1
end_of_record
''');
          final failure = CoverdeCheckCoverageBelowMinimumFailure(
            minimumCoverage: 75,
            traceFile: traceFile,
          );

          final result = failure.traceFile;

          expect(result, traceFile);
        },
      );
    });
  });
}
