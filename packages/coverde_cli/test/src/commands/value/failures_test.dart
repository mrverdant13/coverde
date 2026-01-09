// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/value/failures.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeValueFailure', () {
    group('$CoverdeValueTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          final failure = CoverdeValueTraceFileNotFoundFailure(
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
          final failure = CoverdeValueTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeValueEmptyTraceFileFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          final failure = CoverdeValueEmptyTraceFileFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(
            result,
            'No coverage data found in the trace file at '
            '`/path/to/trace.lcov.info`.',
          );
        },
      );

      test(
        'traceFilePath '
        '| returns the trace file path',
        () {
          final failure = CoverdeValueEmptyTraceFileFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeValueFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('File not found', '/path/to/source.dart');
          final failure = CoverdeValueFileReadFailure.fromFileSystemException(
            filePath: '/path/to/source.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read file at `/path/to/source.dart`.\n'
            'File not found',
          );
        },
      );

      test(
        'readableMessage '
        '| includes OS error message when present',
        () {
          final osError = OSError('No such file or directory', 2);
          final exception = FileSystemException(
            'File not found',
            '/path/to/source.dart',
            osError,
          );
          final failure = CoverdeValueFileReadFailure.fromFileSystemException(
            filePath: '/path/to/source.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read file at `/path/to/source.dart`.\n'
            'File not found\n'
            'No such file or directory',
          );
        },
      );

      test(
        'filePath '
        '| returns the file path',
        () {
          final exception = FileSystemException('Error');
          final failure = CoverdeValueFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.dart',
            exception: exception,
          );

          final result = failure.filePath;

          expect(result, '/path/to/file.dart');
        },
      );

      test(
        'errorMessage '
        '| returns the error message',
        () {
          final exception = FileSystemException('Permission denied');
          final failure = CoverdeValueFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.errorMessage;

          expect(result, 'Permission denied');
        },
      );
    });

    group('$CoverdeValueTraceFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path and error message',
        () {
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/trace.lcov.info',
          );
          final failure =
              CoverdeValueTraceFileReadFailure.fromFileSystemException(
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
