// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/rm/failures.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeRmFailure', () {
    group('$CoverdeRmMissingPathsFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with usage',
        () {
          final failure = CoverdeRmMissingPathsFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
A set of file and/or directory paths should be provided.

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          final failure = CoverdeRmMissingPathsFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'A set of file and/or directory paths should be provided.',
          );
        },
      );
    });

    group('$CoverdeRmElementNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with element path',
        () {
          final failure = CoverdeRmElementNotFoundFailure(
            elementPath: '/path/to/element',
          );

          final result = failure.readableMessage;

          expect(result, 'The </path/to/element> element does not exist.');
        },
      );

      test(
        'elementPath '
        '| returns the element path',
        () {
          final failure = CoverdeRmElementNotFoundFailure(
            elementPath: '/path/to/file',
          );

          final result = failure.elementPath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeRmFileDeleteFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/file.txt');
          final failure = CoverdeRmFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/file.txt',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to delete file at `/path/to/file.txt`.\n'
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
            '/path/to/file.txt',
            osError,
          );
          final failure = CoverdeRmFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/file.txt',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to delete file at `/path/to/file.txt`.\n'
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
          final failure = CoverdeRmFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/element',
            exception: exception,
          );

          final result = failure.filePath;

          expect(result, '/path/to/element');
        },
      );

      test(
        'operation '
        '| returns the delete operation',
        () {
          final exception = FileSystemException('Error');
          final failure = CoverdeRmFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeRmFileOperation.delete);
        },
      );
    });

    group('$CoverdeRmDirectoryDeleteFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with directory path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/dir');
          final failure =
              CoverdeRmDirectoryDeleteFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to delete directory at `/path/to/dir`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'readableMessage '
        '| includes OS error message when present',
        () {
          final osError = OSError('Directory not empty', 39);
          final exception =
              FileSystemException('Cannot remove', '/path/to/dir', osError);
          final failure =
              CoverdeRmDirectoryDeleteFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to delete directory at `/path/to/dir`.\n'
            'Cannot remove\n'
            'Directory not empty',
          );
        },
      );

      test(
        'directoryPath '
        '| returns the directory path',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeRmDirectoryDeleteFailure.fromFileSystemException(
            directoryPath: '/path/to/element',
            exception: exception,
          );

          final result = failure.directoryPath;

          expect(result, '/path/to/element');
        },
      );

      test(
        'operation '
        '| returns the delete operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeRmDirectoryDeleteFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeRmDirectoryOperation.delete);
        },
      );
    });
  });
}
