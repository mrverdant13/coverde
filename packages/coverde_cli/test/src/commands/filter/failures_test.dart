// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/filter/failures.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeFilterFailure', () {
    group('$CoverdeFilterInvalidRegexPatternFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with invalid regex pattern and exception',
        () {
          final exception = FormatException('Invalid regex pattern');
          final failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: '[invalid',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid regex pattern: `[invalid`.
Invalid regex pattern

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns formatted description with pattern and exception message',
        () {
          final exception = FormatException('Unmatched bracket');
          final failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: '[unclosed',
            exception: exception,
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Invalid regex pattern: `[unclosed`.\n'
            'Unmatched bracket',
          );
        },
      );

      test(
        'invalidRegexPattern '
        '| returns the invalid regex pattern',
        () {
          final exception = FormatException('Error');
          final failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: 'test[pattern',
            exception: exception,
          );

          final result = failure.invalidRegexPattern;

          expect(result, 'test[pattern');
        },
      );

      test(
        'exception '
        '| returns the underlying FormatException',
        () {
          final exception = FormatException('Custom error message');
          final failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: 'pattern',
            exception: exception,
          );

          final result = failure.exception;

          expect(result, exception);
          expect(result.message, 'Custom error message');
        },
      );
    });

    group('$CoverdeFilterTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          final failure = CoverdeFilterTraceFileNotFoundFailure(
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
          final failure = CoverdeFilterTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeFilterFileWriteFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/file');
          final failure = CoverdeFilterFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to write file at `/path/to/file`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'readableMessage '
        '| includes OS error message when present',
        () {
          final osError = OSError('Access denied', 13);
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/file',
            osError,
          );
          final failure = CoverdeFilterFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to write file at `/path/to/file`.\n'
            'Permission denied\n'
            'Access denied',
          );
        },
      );

      test(
        'filePath '
        '| returns the file path',
        () {
          final exception = FileSystemException('Error');
          final failure = CoverdeFilterFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/output.txt',
            exception: exception,
          );

          final result = failure.filePath;

          expect(result, '/path/to/output.txt');
        },
      );

      test(
        'operation '
        '| returns the write operation',
        () {
          final exception = FileSystemException('Error');
          final failure = CoverdeFilterFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeFilterFileOperation.write);
        },
      );

      test(
        'errorMessage '
        '| returns the error message',
        () {
          final exception = FileSystemException('Disk full');
          final failure = CoverdeFilterFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.errorMessage;

          expect(result, 'Disk full');
        },
      );
    });

    group('$CoverdeFilterDirectoryCreateFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with directory path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/dir');
          final failure =
              CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to create directory at `/path/to/dir`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'readableMessage '
        '| includes OS error message when present',
        () {
          final osError = OSError('Access denied', 13);
          final exception =
              FileSystemException('Permission denied', '/path/to/dir', osError);
          final failure =
              CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to create directory at `/path/to/dir`.\n'
            'Permission denied\n'
            'Access denied',
          );
        },
      );

      test(
        'directoryPath '
        '| returns the directory path',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
            directoryPath: '/path/to/parent',
            exception: exception,
          );

          final result = failure.directoryPath;

          expect(result, '/path/to/parent');
        },
      );

      test(
        'operation '
        '| returns the create operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeFilterDirectoryOperation.create);
        },
      );

      test(
        'errorMessage '
        '| returns the error message',
        () {
          final exception = FileSystemException('Path too long');
          final failure =
              CoverdeFilterDirectoryCreateFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.errorMessage;

          expect(result, 'Path too long');
        },
      );
    });

    group('$CoverdeFilterTraceFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path and error message',
        () {
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/trace.lcov.info',
          );
          final failure =
              CoverdeFilterTraceFileReadFailure.fromFileSystemException(
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
