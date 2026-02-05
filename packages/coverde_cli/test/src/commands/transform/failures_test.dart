// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/commands/transform/failures.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  group('$CoverdeTransformFailure', () {
    group('$CoverdeTransformInvalidConfigFileFailure', () {
      group('readableMessage', () {
        test('| returns formatted message for invalid YAML failure', () {
          late yaml.YamlException yamlException;
          try {
            yaml.loadYaml('invalid: [unclosed');
            fail('Expected YamlException');
          } on yaml.YamlException catch (e) {
            yamlException = e;
          }
          final failure = CoverdeConfigFromYamlInvalidYamlFailure(
            yamlString: 'invalid: [unclosed',
            yamlException: yamlException,
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: '/path/to/coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `/path/to/coverde.yaml`.',
              'Invalid YAML: ${yamlException.message}.',
            ].join('\n'),
          );
        });

        test('| returns formatted message for invalid YAML member type failure',
            () {
          const failure = CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: 'presets',
            expectedType: String,
            value: 123,
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Invalid YAML member type.',
              'Key: `presets`.',
              'Expected type: `String`.',
              'Value: `123`.',
            ].join('\n'),
          );
        });

        test('| returns formatted message for invalid YAML root type failure ',
            () {
          const failure = CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: null,
            expectedType: Map,
            value: 'not a map',
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Invalid YAML member type.',
              'Key: `<root>`.',
              'Expected type: `Map<dynamic, dynamic>`.',
              'Value: `not a map`.',
            ].join('\n'),
          );
        });

        test(
            '| returns formatted message for invalid YAML member value failure '
            'with hint', () {
          const failure = CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
            key: 'transformations',
            value: 'invalid',
            hint: 'Expected a number string',
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Invalid YAML member value.',
              'Key: `transformations`.',
              'Hint: Expected a number string.',
              'Value: `invalid`.',
            ].join('\n'),
          );
        });

        test(
            '| returns formatted message for invalid YAML member value failure '
            'without hint', () {
          const failure = CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
            key: 'preset',
            value: null,
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Invalid YAML member value.',
              'Key: `preset`.',
              'Value: `null`.',
            ].join('\n'),
          );
        });

        test('| returns formatted message for unknown preset failure', () {
          const failure = CoverdeConfigFromYamlUnknownPresetFailure(
            unknownPreset: 'missing',
            availablePresets: ['preset1', 'preset2'],
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: '/config/coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `/config/coverde.yaml`.',
              'Unknown preset: `missing`.',
              'Available presets:',
              '- `preset1`',
              '- `preset2`',
            ].join('\n'),
          );
        });

        test('| returns formatted message for preset cycle failure', () {
          const failure = CoverdeConfigFromYamlPresetCycleFailure(
            cycle: ['a', 'b', 'a'],
          );
          final transformFailure = CoverdeTransformInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: failure,
          );

          final result = transformFailure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Preset cycle detected: a -> b -> a.',
            ].join('\n'),
          );
        });
      });
    });

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
