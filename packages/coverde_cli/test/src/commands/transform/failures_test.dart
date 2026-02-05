// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/transform/failures.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

void main() {
  group('$CoverdeTransformFailure', () {
    group('$CoverdeTransformInvalidTransformCliOptionFailure', () {
      group('readableMessage', () {
        test('| returns formatted message for unknown preset failure', () {
          const failure = TransformationFromCliOptionUnknownPresetFailure(
            unknownPreset: 'nonexistent',
            availablePresets: ['default', 'ci'],
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Unknown preset: `nonexistent`.',
              'Available presets:',
              '- `default`',
              '- `ci`',
            ].join('\n'),
          );
        });

        test(
            '| returns formatted message '
            'for unsupported transformation failure', () {
          const failure =
              TransformationFromCliOptionUnsupportedTransformationFailure(
            unsupportedTransformation: 'unknown_transform',
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Unsupported transformation: `unknown_transform`.',
            ].join('\n'),
          );
        });

        test('| returns formatted message for invalid regex pattern failure',
            () {
          const failure = TransformationFromCliOptionInvalidRegexPatternFailure(
            transformationIdentifier: 'keep',
            regex: '[invalid',
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Transformation: `keep`.',
              'Invalid regex pattern: `[invalid`.',
            ].join('\n'),
          );
        });

        test('| returns formatted message for invalid glob pattern failure',
            () {
          const failure = TransformationFromCliOptionInvalidGlobPatternFailure(
            transformationIdentifier: 'rewrite',
            glob: '**/invalid{',
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Transformation: `rewrite`.',
              'Invalid glob pattern: `**/invalid{`.',
            ].join('\n'),
          );
        });

        test(
            '| returns formatted message '
            'for invalid numeric comparison failure', () {
          const failure =
              TransformationFromCliOptionInvalidNumericComparisonFailure(
            transformationIdentifier: 'keep-by-coverage',
            comparison: 'invalid',
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Transformation: `keep-by-coverage`.',
              'Invalid numeric comparison: `invalid`.',
            ].join('\n'),
          );
        });

        test(
            '| returns formatted message '
            'for invalid coverage percentage failure', () {
          const failure =
              TransformationFromCliOptionInvalidCoveragePercentageFailure(
            transformationIdentifier: 'keep-by-coverage',
            invalidReferences: [150],
          );
          final transformFailure =
              CoverdeTransformInvalidTransformCliOptionFailure(
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid transformation CLI option.',
              'Transformation: `keep-by-coverage`.',
              'Coverage values must be between 0 and 100.',
              'Invalid values: 150.0.',
            ].join('\n'),
          );
        });
      });
    });

    group('$CoverdeTransformTraceFileNotFoundFailure', () {
      group('readableMessage', () {
        test('| returns formatted message with trace file path', () {
          final failure = CoverdeTransformTraceFileNotFoundFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(
            result,
            'No trace file found at `/path/to/trace.lcov.info`.',
          );
        });
      });
    });

    group('$CoverdeTransformFileOperationFailure', () {
      group('$CoverdeTransformFileReadFailure', () {
        group('readableMessage', () {
          test(
              '| returns formatted message from FileSystemException '
              'without OS error', () {
            final exception = FileSystemException(
              'Permission denied',
              '/path/to/trace.lcov.info',
            );
            final failure =
                CoverdeTransformFileReadFailure.fromFileSystemException(
              filePath: '/path/to/trace.lcov.info',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to read file at `/path/to/trace.lcov.info`.',
                'Permission denied',
              ].join('\n'),
            );
          });

          test(
              '| returns formatted message from FileSystemException '
              'with OS error', () {
            final osError = OSError('Access denied', 13);
            final exception = FileSystemException(
              'Permission denied',
              '/path/to/trace.lcov.info',
              osError,
            );
            final failure =
                CoverdeTransformFileReadFailure.fromFileSystemException(
              filePath: '/path/to/trace.lcov.info',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to read file at `/path/to/trace.lcov.info`.',
                'Permission denied',
                'Access denied',
              ].join('\n'),
            );
          });
        });
      });

      group('$CoverdeTransformFileWriteFailure', () {
        group('readableMessage', () {
          test(
              '| returns formatted message from FileSystemException '
              'without OS error', () {
            final exception =
                FileSystemException('Permission denied', '/path/to/file');
            final failure =
                CoverdeTransformFileWriteFailure.fromFileSystemException(
              filePath: '/path/to/file',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to write file at `/path/to/file`.',
                'Permission denied',
              ].join('\n'),
            );
          });

          test(
              '| returns formatted message from FileSystemException '
              'with OS error', () {
            final osError = OSError('Access denied', 13);
            final exception = FileSystemException(
              'Permission denied',
              '/path/to/file',
              osError,
            );
            final failure =
                CoverdeTransformFileWriteFailure.fromFileSystemException(
              filePath: '/path/to/file',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to write file at `/path/to/file`.',
                'Permission denied',
                'Access denied',
              ].join('\n'),
            );
          });
        });
      });
    });

    group('$CoverdeTransformDirectoryOperationFailure', () {
      group('$CoverdeTransformDirectoryCreateFailure', () {
        group('readableMessage', () {
          test(
              '| returns formatted message from FileSystemException '
              'without OS error', () {
            final exception =
                FileSystemException('Permission denied', '/path/to/dir');
            final failure =
                CoverdeTransformDirectoryCreateFailure.fromFileSystemException(
              directoryPath: '/path/to/dir',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to create directory at `/path/to/dir`.',
                'Permission denied',
              ].join('\n'),
            );
          });

          test(
              '| returns formatted message from FileSystemException '
              'with OS error', () {
            final osError = OSError('Access denied', 13);
            final exception = FileSystemException(
              'Permission denied',
              '/path/to/dir',
              osError,
            );
            final failure =
                CoverdeTransformDirectoryCreateFailure.fromFileSystemException(
              directoryPath: '/path/to/dir',
              exception: exception,
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Failed to create directory at `/path/to/dir`.',
                'Permission denied',
                'Access denied',
              ].join('\n'),
            );
          });
        });
      });
    });
  });
}
