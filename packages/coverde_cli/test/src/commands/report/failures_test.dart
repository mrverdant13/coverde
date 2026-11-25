// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/report/failures.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$CoverdeReportFailure', () {
    group('$CoverdeReportInvalidMediumThresholdFailure', () {
      test('readableMessage '
          '| returns formatted message with invalid raw value', () {
        final failure = CoverdeReportInvalidMediumThresholdFailure(
          usageMessage: 'Usage message',
          rawValue: 'invalid',
        );

        final result = failure.readableMessage;

        expect(result, '''
Invalid medium threshold: `invalid`.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''');
      });

      test('rawValue '
          '| returns the raw value', () {
        final failure = CoverdeReportInvalidMediumThresholdFailure(
          usageMessage: 'Usage message',
          rawValue: 'test',
        );

        final result = failure.rawValue;

        expect(result, 'test');
      });
    });

    group('$CoverdeReportInvalidHighThresholdFailure', () {
      test('readableMessage '
          '| returns formatted message with invalid raw value', () {
        final failure = CoverdeReportInvalidHighThresholdFailure(
          usageMessage: 'Usage message',
          rawValue: 'invalid',
        );

        final result = failure.readableMessage;

        expect(result, '''
Invalid high threshold: `invalid`.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''');
      });

      test('rawValue '
          '| returns the raw value', () {
        final failure = CoverdeReportInvalidHighThresholdFailure(
          usageMessage: 'Usage message',
          rawValue: 'test',
        );

        final result = failure.rawValue;

        expect(result, 'test');
      });
    });

    group('$CoverdeReportInvalidThresholdRelationshipFailure', () {
      test('readableMessage '
          '| returns formatted message with threshold values', () {
        final failure = CoverdeReportInvalidThresholdRelationshipFailure(
          usageMessage: 'Usage message',
          mediumValue: 90,
          highValue: 75,
        );

        final result = failure.readableMessage;

        expect(result, '''
Medium threshold (90.0) must be less than high threshold (75.0).

Usage message
''');
      });

      test('mediumValue '
          '| returns the medium value', () {
        final failure = CoverdeReportInvalidThresholdRelationshipFailure(
          usageMessage: 'Usage message',
          mediumValue: 80,
          highValue: 90,
        );

        final result = failure.mediumValue;

        expect(result, 80);
      });

      test('highValue '
          '| returns the high value', () {
        final failure = CoverdeReportInvalidThresholdRelationshipFailure(
          usageMessage: 'Usage message',
          mediumValue: 80,
          highValue: 90,
        );

        final result = failure.highValue;

        expect(result, 90);
      });
    });

    group('$CoverdeReportTraceFileNotFoundFailure', () {
      test('readableMessage '
          '| returns formatted message with trace file path', () {
        final failure = CoverdeReportTraceFileNotFoundFailure(
          traceFilePath: '/path/to/trace.lcov.info',
        );

        final result = failure.readableMessage;

        expect(result, 'No trace file found at `/path/to/trace.lcov.info`.');
      });

      test('traceFilePath '
          '| returns the trace file path', () {
        final failure = CoverdeReportTraceFileNotFoundFailure(
          traceFilePath: '/path/to/file',
        );

        final result = failure.traceFilePath;

        expect(result, '/path/to/file');
      });
    });

    group('$CoverdeReportEmptyTraceFileFailure', () {
      test('readableMessage '
          '| returns formatted message with trace file path', () {
        final failure = CoverdeReportEmptyTraceFileFailure(
          traceFilePath: '/path/to/trace.lcov.info',
        );

        final result = failure.readableMessage;

        expect(
          result,
          'No coverage data found in the trace file at '
          '`/path/to/trace.lcov.info`.',
        );
      });

      test('traceFilePath '
          '| returns the trace file path', () {
        final failure = CoverdeReportEmptyTraceFileFailure(
          traceFilePath: '/path/to/file',
        );

        final result = failure.traceFilePath;

        expect(result, '/path/to/file');
      });
    });

    group('$CoverdeReportFileReadFailure', () {
      test('readableMessage '
          '| returns formatted message with file path and error message', () {
        final exception = FileSystemException(
          'File not found',
          '/path/to/trace.lcov.info',
        );
        final failure = CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: '/path/to/trace.lcov.info',
          exception: exception,
        );

        final result = failure.readableMessage;

        expect(
          result,
          'Failed to read file at `/path/to/trace.lcov.info`.\n'
          'File not found',
        );
      });

      test('readableMessage '
          '| includes OS error message when present', () {
        final osError = OSError('No such file or directory', 2);
        final exception = FileSystemException(
          'File not found',
          '/path/to/trace.lcov.info',
          osError,
        );
        final failure = CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: '/path/to/trace.lcov.info',
          exception: exception,
        );

        final result = failure.readableMessage;

        expect(
          result,
          'Failed to read file at `/path/to/trace.lcov.info`.\n'
          'File not found\n'
          'No such file or directory',
        );
      });

      test('filePath '
          '| returns the file path', () {
        final exception = FileSystemException('Error');
        final failure = CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: '/path/to/file',
          exception: exception,
        );

        final result = failure.filePath;

        expect(result, '/path/to/file');
      });

      test('readableMessage '
          '| formats a failure built with an error message', () {
        final failure = CoverdeReportFileReadFailure(
          filePath: '/path/to/file',
          errorMessage: 'denied',
        );

        final result = failure.readableMessage;

        expect(
          result,
          'Failed to read file at `/path/to/file`.\n'
          'denied',
        );
      });

      test('operation '
          '| returns the read operation', () {
        final exception = FileSystemException('Error');
        final failure = CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: '/path/to/file',
          exception: exception,
        );

        final result = failure.operation;

        expect(result, CoverdeReportFileOperation.read);
      });
    });

    group('$CoverdeReportUnresolvedCoveragePathFailure', () {
      test('readableMessage '
          '| names the path that cannot be resolved', () {
        const failure = CoverdeReportUnresolvedCoveragePathFailure(
          sourcePath: r'C:\lib\a.dart',
        );

        final result = failure.readableMessage;

        expect(
          result,
          r'Coverage path `C:\lib\a.dart` cannot be resolved '
          'on this operating system.',
        );
      });
    });

    group('$CoverdeReportTraceFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path and error message',
        () {
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/trace.lcov.info',
          );
          final failure =
              CoverdeReportTraceFileReadFailure.fromFileSystemException(
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
  });
}
