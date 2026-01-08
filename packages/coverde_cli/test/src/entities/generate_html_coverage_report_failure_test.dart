// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/entities/generate_html_coverage_report_failure.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$GenerateHtmlCoverageReportFailure', () {
    group('$GenerateHtmlCoverageReportFileOperationFailure', () {
      test(
        'readableMessage '
        '| returns formatted message '
        'with file path, operation, and error message',
        () {
          final failure = GenerateHtmlCoverageReportFileWriteFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: FileSystemException('Permission denied'),
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to write file at `/path/to/file.html`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'filePath '
        '| returns the file path',
        () {
          final failure =
              GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: FileSystemException('Error'),
          );

          final result = failure.filePath;

          expect(result, '/path/to/file.html');
        },
      );

      test(
        'operation '
        '| returns the operation',
        () {
          final failure = GenerateHtmlCoverageReportFileCreateFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: FileSystemException('Error'),
          );

          final result = failure.operation;

          expect(result, GenerateHtmlCoverageReportFileOperation.create);
        },
      );

      test(
        'errorMessage '
        '| returns the error message',
        () {
          final failure = GenerateHtmlCoverageReportFileWriteFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: FileSystemException('No space left on device'),
          );

          final result = failure.errorMessage;

          expect(result, 'No space left on device');
        },
      );
    });

    group('$GenerateHtmlCoverageReportFileCreateFailure', () {
      test(
        'fromFileSystemException '
        '| creates failure with error message from exception',
        () {
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/file.html',
          );
          final failure = GenerateHtmlCoverageReportFileCreateFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(failure.filePath, '/path/to/file.html');
          expect(
            failure.operation,
            GenerateHtmlCoverageReportFileOperation.create,
          );
          expect(failure.errorMessage, 'Permission denied');
        },
      );

      test(
        'fromFileSystemException '
        '| includes OS error message when present',
        () {
          final osError = OSError('No such file or directory', 2);
          final exception = FileSystemException(
            'Permission denied',
            '/path/to/file.html',
            osError,
          );
          final failure = GenerateHtmlCoverageReportFileCreateFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(
            failure.errorMessage,
            'Permission denied\nNo such file or directory',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message',
        () {
          final exception = FileSystemException('Permission denied');
          final failure = GenerateHtmlCoverageReportFileCreateFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to create file at `/path/to/file.html`.\n'
            'Permission denied',
          );
        },
      );
    });

    group('$GenerateHtmlCoverageReportFileReadFailure', () {
      test(
        'fromFileSystemException '
        '| creates failure with error message from exception',
        () {
          final exception = FileSystemException(
            'File not found',
            '/path/to/file.html',
          );
          final failure =
              GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(failure.filePath, '/path/to/file.html');
          expect(
            failure.operation,
            GenerateHtmlCoverageReportFileOperation.read,
          );
          expect(failure.errorMessage, 'File not found');
        },
      );

      test(
        'fromFileSystemException '
        '| includes OS error message when present',
        () {
          final osError = OSError('No such file or directory', 2);
          final exception = FileSystemException(
            'File not found',
            '/path/to/file.html',
            osError,
          );
          final failure =
              GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(
            failure.errorMessage,
            'File not found\nNo such file or directory',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message',
        () {
          final exception = FileSystemException('File not found');
          final failure =
              GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read file at `/path/to/file.html`.\n'
            'File not found',
          );
        },
      );
    });

    group('$GenerateHtmlCoverageReportFileWriteFailure', () {
      test(
        'fromFileSystemException '
        '| creates failure with error message from exception',
        () {
          final exception = FileSystemException(
            'No space left on device',
            '/path/to/file.html',
          );
          final failure = GenerateHtmlCoverageReportFileWriteFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(failure.filePath, '/path/to/file.html');
          expect(
            failure.operation,
            GenerateHtmlCoverageReportFileOperation.write,
          );
          expect(failure.errorMessage, 'No space left on device');
        },
      );

      test(
        'fromFileSystemException '
        '| includes OS error message when present',
        () {
          final osError = OSError('No space left on device', 28);
          final exception = FileSystemException(
            'Write failed',
            '/path/to/file.html',
            osError,
          );
          final failure = GenerateHtmlCoverageReportFileWriteFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          expect(
            failure.errorMessage,
            'Write failed\nNo space left on device',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message',
        () {
          final exception = FileSystemException('No space left on device');
          final failure = GenerateHtmlCoverageReportFileWriteFailure
              .fromFileSystemException(
            filePath: '/path/to/file.html',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to write file at `/path/to/file.html`.\n'
            'No space left on device',
          );
        },
      );
    });
  });
}
