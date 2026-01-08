// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/optimize_tests/failures.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeOptimizeTestsFailure', () {
    group('$CoverdeOptimizeTestsPubspecNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with project directory path',
        () {
          final failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
No pubspec.yaml file found in /path/to/project.

Usage message
''',
          );
        },
      );

      test(
        'projectDirPath '
        '| returns the project directory path',
        () {
          final failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.projectDirPath;

          expect(result, '/path/to/project');
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          final failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.invalidInputDescription;

          expect(result, 'No pubspec.yaml file found in /path/to/project.');
        },
      );
    });

    group('$CoverdeOptimizeTestsFileReadFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('File not found', '/path/to/file.dart');
          final failure =
              CoverdeOptimizeTestsFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read file at `/path/to/file.dart`.\n'
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
            '/path/to/file.dart',
            osError,
          );
          final failure =
              CoverdeOptimizeTestsFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to read file at `/path/to/file.dart`.\n'
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
          final failure =
              CoverdeOptimizeTestsFileReadFailure.fromFileSystemException(
            filePath: '/path/to/pubspec.yaml',
            exception: exception,
          );

          final result = failure.filePath;

          expect(result, '/path/to/pubspec.yaml');
        },
      );

      test(
        'operation '
        '| returns the read operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeOptimizeTestsFileReadFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeOptimizeTestsFileOperation.read);
        },
      );
    });

    group('$CoverdeOptimizeTestsFileWriteFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/output.dart');
          final failure =
              CoverdeOptimizeTestsFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/output.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to write file at `/path/to/output.dart`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'operation '
        '| returns the write operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeOptimizeTestsFileWriteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeOptimizeTestsFileOperation.write);
        },
      );
    });

    group('$CoverdeOptimizeTestsFileDeleteFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with file path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/file.dart');
          final failure =
              CoverdeOptimizeTestsFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/file.dart',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to delete file at `/path/to/file.dart`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'operation '
        '| returns the delete operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeOptimizeTestsFileDeleteFailure.fromFileSystemException(
            filePath: '/path/to/file',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeOptimizeTestsFileOperation.delete);
        },
      );
    });

    group('$CoverdeOptimizeTestsDirectoryListFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with directory path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/dir');
          final failure =
              CoverdeOptimizeTestsDirectoryListFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            'Failed to list directory at `/path/to/dir`.\n'
            'Permission denied',
          );
        },
      );

      test(
        'directoryPath '
        '| returns the directory path',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeOptimizeTestsDirectoryListFailure.fromFileSystemException(
            directoryPath: '/path/to/project',
            exception: exception,
          );

          final result = failure.directoryPath;

          expect(result, '/path/to/project');
        },
      );

      test(
        'operation '
        '| returns the list operation',
        () {
          final exception = FileSystemException('Error');
          final failure =
              CoverdeOptimizeTestsDirectoryListFailure.fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeOptimizeTestsDirectoryOperation.list);
        },
      );
    });

    group('$CoverdeOptimizeTestsDirectoryCreateFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with directory path and error message',
        () {
          final exception =
              FileSystemException('Permission denied', '/path/to/dir');
          final failure = CoverdeOptimizeTestsDirectoryCreateFailure
              .fromFileSystemException(
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
        'operation '
        '| returns the create operation',
        () {
          final exception = FileSystemException('Error');
          final failure = CoverdeOptimizeTestsDirectoryCreateFailure
              .fromFileSystemException(
            directoryPath: '/path/to/dir',
            exception: exception,
          );

          final result = failure.operation;

          expect(result, CoverdeOptimizeTestsDirectoryOperation.create);
        },
      );
    });
  });
}
