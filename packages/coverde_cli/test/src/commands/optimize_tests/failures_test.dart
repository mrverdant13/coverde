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

    group('$CoverdeOptimizeTestsShardOptionsMismatchFailure', () {
      test(
        'readableMessage '
        '| returns formatted message '
        'when total-shards is provided without shard-index',
        () {
          final failure = CoverdeOptimizeTestsShardOptionsMismatchFailure(
            usageMessage: 'Usage message',
            totalShardsProvided: true,
            shardIndexProvided: false,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Both total-shards and shard-index must be provided together. Got: total-shards=provided, shard-index=not provided.

Usage message
''',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message '
        'when shard-index is provided without total-shards',
        () {
          final failure = CoverdeOptimizeTestsShardOptionsMismatchFailure(
            usageMessage: 'Usage message',
            totalShardsProvided: false,
            shardIndexProvided: true,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Both total-shards and shard-index must be provided together. Got: total-shards=not provided, shard-index=provided.

Usage message
''',
          );
        },
      );

      test(
        'totalShardsProvided '
        '| returns whether total-shards was provided',
        () {
          final failure = CoverdeOptimizeTestsShardOptionsMismatchFailure(
            usageMessage: 'Usage message',
            totalShardsProvided: true,
            shardIndexProvided: false,
          );

          final result = failure.totalShardsProvided;

          expect(result, isTrue);
        },
      );

      test(
        'shardIndexProvided '
        '| returns whether shard-index was provided',
        () {
          final failure = CoverdeOptimizeTestsShardOptionsMismatchFailure(
            usageMessage: 'Usage message',
            totalShardsProvided: true,
            shardIndexProvided: false,
          );

          final result = failure.shardIndexProvided;

          expect(result, isFalse);
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          final failure = CoverdeOptimizeTestsShardOptionsMismatchFailure(
            usageMessage: 'Usage message',
            totalShardsProvided: true,
            shardIndexProvided: false,
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Both total-shards and shard-index must be provided together. '
            'Got: total-shards=provided, shard-index=not provided.',
          );
        },
      );
    });

    group('$CoverdeOptimizeTestsInvalidShardOptionsFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with invalid total-shards value',
        () {
          final failure = CoverdeOptimizeTestsInvalidShardOptionsFailure(
            usageMessage: 'Usage message',
            totalShardsStr: 'abc',
            shardIndexStr: '0',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid shard options: total-shards=abc shard-index=0. Both values must be integers.

Usage message
''',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message with invalid shard-index value',
        () {
          final failure = CoverdeOptimizeTestsInvalidShardOptionsFailure(
            usageMessage: 'Usage message',
            totalShardsStr: '4',
            shardIndexStr: 'xyz',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid shard options: total-shards=4 shard-index=xyz. Both values must be integers.

Usage message
''',
          );
        },
      );

      test(
        'totalShardsStr '
        '| returns the unparsed total shards value',
        () {
          final failure = CoverdeOptimizeTestsInvalidShardOptionsFailure(
            usageMessage: 'Usage message',
            totalShardsStr: 'not_an_int',
            shardIndexStr: '0',
          );

          final result = failure.totalShardsStr;

          expect(result, 'not_an_int');
        },
      );

      test(
        'shardIndexStr '
        '| returns the unparsed shard index value',
        () {
          final failure = CoverdeOptimizeTestsInvalidShardOptionsFailure(
            usageMessage: 'Usage message',
            totalShardsStr: '4',
            shardIndexStr: 'not_an_int',
          );

          final result = failure.shardIndexStr;

          expect(result, 'not_an_int');
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          final failure = CoverdeOptimizeTestsInvalidShardOptionsFailure(
            usageMessage: 'Usage message',
            totalShardsStr: 'abc',
            shardIndexStr: 'xyz',
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Invalid shard options: total-shards=abc shard-index=xyz. '
            'Both values must be integers.',
          );
        },
      );
    });

    group('$CoverdeOptimizeTestsShardIndexOutOfRangeFailure', () {
      test(
        'readableMessage '
        '| returns formatted message when shard-index >= total-shards',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 4,
            shardIndex: 5,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Shard index out of range: shard-index=5 must be between 0 and 3 (total-shards=4).

Usage message
''',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message when total-shards <= 0',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 0,
            shardIndex: 0,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Shard index out of range: shard-index=0 must be between 0 and -1 (total-shards=0).

Usage message
''',
          );
        },
      );

      test(
        'readableMessage '
        '| returns formatted message when shard-index < 0',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 4,
            shardIndex: -1,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Shard index out of range: shard-index=-1 must be between 0 and 3 (total-shards=4).

Usage message
''',
          );
        },
      );

      test(
        'totalShards '
        '| returns the total number of shards',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 8,
            shardIndex: 4,
          );

          final result = failure.totalShards;

          expect(result, 8);
        },
      );

      test(
        'shardIndex '
        '| returns the shard index that was out of range',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 4,
            shardIndex: 10,
          );

          final result = failure.shardIndex;

          expect(result, 10);
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          final failure = CoverdeOptimizeTestsShardIndexOutOfRangeFailure(
            usageMessage: 'Usage message',
            totalShards: 4,
            shardIndex: 5,
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Shard index out of range: shard-index=5 must be between 0 and 3 '
            '(total-shards=4).',
          );
        },
      );
    });
  });
}
