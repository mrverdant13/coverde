import 'package:coverde/src/commands/check/failures.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/reporting/models/coverage_document.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  group('$CoverdeCheckFailure', () {
    group('$CoverdeCheckMoreThanOneArgumentFailure', () {
      test('readableMessage '
          '| returns formatted message with usage', () {
        const failure = CoverdeCheckMoreThanOneArgumentFailure(
          usageMessage: 'Usage message',
        );

        final result = failure.readableMessage;

        expect(result, '''
Only one argument (minimum coverage threshold) is expected.

Usage message
''');
      });

      test('invalidInputDescription '
          '| returns the invalid input description', () {
        const failure = CoverdeCheckMoreThanOneArgumentFailure(
          usageMessage: 'Usage message',
        );

        final result = failure.invalidInputDescription;

        expect(
          result,
          'Only one argument (minimum coverage threshold) is expected.',
        );
      });
    });

    group('$CoverdeCheckMissingMinimumCoverageThresholdFailure', () {
      test('readableMessage '
          '| returns formatted message with usage', () {
        const failure = CoverdeCheckMissingMinimumCoverageThresholdFailure(
          usageMessage: 'Usage message',
        );

        final result = failure.readableMessage;

        expect(result, '''
Missing minimum coverage threshold.

Usage message
''');
      });

      test('invalidInputDescription '
          '| returns the invalid input description', () {
        const failure = CoverdeCheckMissingMinimumCoverageThresholdFailure(
          usageMessage: 'Usage message',
        );

        final result = failure.invalidInputDescription;

        expect(result, 'Missing minimum coverage threshold.');
      });
    });

    group('$CoverdeCheckInvalidMinimumCoverageThresholdFailure', () {
      test('readableMessage '
          '| returns formatted message with usage', () {
        const failure = CoverdeCheckInvalidMinimumCoverageThresholdFailure(
          usageMessage: 'Usage message',
        );

        final result = failure.readableMessage;

        expect(result, '''
Invalid minimum coverage threshold.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''');
      });

      test('invalidInputDescription '
          '| returns the invalid input description', () {
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
      });
    });

    group('$CoverdeCheckUnknownCoverageThresholdFailure', () {
      test('readableMessage '
          '| lists the available threshold names', () {
        const failure = CoverdeCheckUnknownCoverageThresholdFailure(
          thresholdName: 'packages',
          configPath: '/repo/coverde.yaml',
          availableThresholds: ['minimum', 'repo'],
        );

        final result = failure.readableMessage;

        expect(result, '''
Unknown coverage threshold `packages` in `/repo/coverde.yaml`.
Available thresholds: `minimum`, `repo`.
''');
      });

      test('readableMessage '
          '| reports none when no thresholds are defined', () {
        const failure = CoverdeCheckUnknownCoverageThresholdFailure(
          thresholdName: 'minimum',
          configPath: '/repo/coverde.yaml',
          availableThresholds: [],
        );

        final result = failure.readableMessage;

        expect(result, '''
Unknown coverage threshold `minimum` in `/repo/coverde.yaml`.
Available thresholds: none.
''');
      });
    });

    group('$CoverdeCheckConfigFileReadFailure', () {
      test('readableMessage '
          '| returns the formatted message without an OS error', () {
        final failure =
            CoverdeCheckConfigFileReadFailure.fromFileSystemException(
              configPath: '/repo/coverde.yaml',
              exception: const FileSystemException(
                'Permission denied',
                '/repo/coverde.yaml',
              ),
            );

        final result = failure.readableMessage;

        expect(
          result,
          'Failed to read config file at `/repo/coverde.yaml`.\n'
          'Permission denied',
        );
      });

      test('readableMessage '
          '| returns the formatted message with an OS error', () {
        final failure =
            CoverdeCheckConfigFileReadFailure.fromFileSystemException(
              configPath: '/repo/coverde.yaml',
              exception: const FileSystemException(
                'Permission denied',
                '/repo/coverde.yaml',
                OSError('Access denied', 13),
              ),
            );

        final result = failure.readableMessage;

        expect(
          result,
          'Failed to read config file at `/repo/coverde.yaml`.\n'
          'Permission denied\n'
          'Access denied',
        );
      });
    });

    group('$CoverdeCheckInvalidConfigFileFailure', () {
      group('readableMessage', () {
        test('| returns formatted message for invalid YAML failure', () {
          late yaml.YamlException yamlException;
          try {
            yaml.loadYaml('invalid: [unclosed');
            fail('Expected YamlException');
          } on yaml.YamlException catch (exception) {
            yamlException = exception;
          }
          final failure = CoverdeCheckInvalidConfigFileFailure(
            configPath: '/path/to/coverde.yaml',
            failure: CoverdeConfigFromYamlInvalidYamlFailure(
              yamlString: 'invalid: [unclosed',
              yamlException: yamlException,
            ),
          );

          final result = failure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `/path/to/coverde.yaml`.',
              'Invalid YAML: ${yamlException.message}.',
            ].join('\n'),
          );
        });

        test(
          '| returns formatted message for invalid YAML member type failure',
          () {
            const failure = CoverdeCheckInvalidConfigFileFailure(
              configPath: 'coverde.yaml',
              failure: CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
                key: 'coverage',
                expectedType: String,
                value: 123,
              ),
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Invalid config file at `coverde.yaml`.',
                'Invalid YAML member type.',
                'Key: `coverage`.',
                'Expected type: `String`.',
                'Value: `123`.',
              ].join('\n'),
            );
          },
        );

        test(
          '| returns formatted message for invalid YAML root type failure',
          () {
            const failure = CoverdeCheckInvalidConfigFileFailure(
              configPath: 'coverde.yaml',
              failure: CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
                key: null,
                expectedType: Map,
                value: 'not a map',
              ),
            );

            final result = failure.readableMessage;

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
          },
        );

        test(
          '| returns formatted message for invalid YAML member value failure '
          'with hint',
          () {
            const failure = CoverdeCheckInvalidConfigFileFailure(
              configPath: 'coverde.yaml',
              failure: CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
                key: 'coverage.[key=95]',
                value: '95',
                hint: 'a non-empty name that is not a number',
              ),
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Invalid config file at `coverde.yaml`.',
                'Invalid YAML member value.',
                'Key: `coverage.[key=95]`.',
                'Hint: a non-empty name that is not a number.',
                'Value: `95`.',
              ].join('\n'),
            );
          },
        );

        test(
          '| returns formatted message for invalid YAML member value failure '
          'without hint',
          () {
            const failure = CoverdeCheckInvalidConfigFileFailure(
              configPath: 'coverde.yaml',
              failure: CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
                key: 'coverage',
                value: null,
              ),
            );

            final result = failure.readableMessage;

            expect(
              result,
              [
                'Invalid config file at `coverde.yaml`.',
                'Invalid YAML member value.',
                'Key: `coverage`.',
                'Value: `null`.',
              ].join('\n'),
            );
          },
        );

        test('| returns formatted message for unknown preset failure', () {
          const failure = CoverdeCheckInvalidConfigFileFailure(
            configPath: '/config/coverde.yaml',
            failure: CoverdeConfigFromYamlUnknownPresetFailure(
              unknownPreset: 'missing',
              availablePresets: ['preset1', 'preset2'],
            ),
          );

          final result = failure.readableMessage;

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
          const failure = CoverdeCheckInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: CoverdeConfigFromYamlPresetCycleFailure(
              cycle: ['a', 'b', 'a'],
            ),
          );

          final result = failure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Preset cycle detected: a -> b -> a.',
            ].join('\n'),
          );
        });

        test('| returns formatted message '
            'for invalid coverage percentage failure', () {
          const failure = CoverdeCheckInvalidConfigFileFailure(
            configPath: 'coverde.yaml',
            failure: CoverdeConfigFromYamlInvalidCoveragePercentageFailure(
              key: 'coverage.repo',
              invalidReferences: [150],
            ),
          );

          final result = failure.readableMessage;

          expect(
            result,
            [
              'Invalid config file at `coverde.yaml`.',
              'Invalid coverage percentage.',
              'Key: `coverage.repo`.',
              'Coverage values must be between 0 and 100.',
              'Invalid values: 150.0.',
            ].join('\n'),
          );
        });
      });
    });

    group('$CoverdeCheckTraceFileNotFoundFailure', () {
      test('readableMessage '
          '| returns formatted message with trace file path', () {
        const failure = CoverdeCheckTraceFileNotFoundFailure(
          traceFilePath: '/path/to/trace.lcov.info',
        );

        final result = failure.readableMessage;

        expect(result, 'No trace file found at `/path/to/trace.lcov.info`.');
      });

      test('traceFilePath '
          '| returns the trace file path', () {
        const failure = CoverdeCheckTraceFileNotFoundFailure(
          traceFilePath: '/path/to/file',
        );

        final result = failure.traceFilePath;

        expect(result, '/path/to/file');
      });
    });

    group('$CoverdeCheckEmptyTraceFileFailure', () {
      test('readableMessage '
          '| returns formatted message with trace file path', () {
        const failure = CoverdeCheckEmptyTraceFileFailure(
          traceFilePath: '/path/to/trace.lcov.info',
        );

        final result = failure.readableMessage;

        expect(
          result,
          'No coverage data found in the trace file located at '
          '`/path/to/trace.lcov.info`.',
        );
      });

      test('traceFilePath '
          '| returns the trace file path', () {
        const failure = CoverdeCheckEmptyTraceFileFailure(
          traceFilePath: '/path/to/file',
        );

        final result = failure.traceFilePath;

        expect(result, '/path/to/file');
      });
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
      test('readableMessage '
          '| returns formatted message with coverage values', () {
        final traceFile = CoverageDocument.parse(
          'SF:path/to/file.dart\nDA:1,1\nDA:2,0\nend_of_record',
        );
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
      });

      test('minimumCoverage '
          '| returns the minimum coverage threshold', () {
        final traceFile = CoverageDocument.parse(
          'SF:path/to/file.dart\nDA:1,1\nend_of_record',
        );
        final failure = CoverdeCheckCoverageBelowMinimumFailure(
          minimumCoverage: 80.5,
          traceFile: traceFile,
        );

        final result = failure.minimumCoverage;

        expect(result, 80.5);
      });

      test('actualCoverage '
          '| returns the actual coverage from trace file', () {
        final traceFile = CoverageDocument.parse(
          'SF:path/to/file.dart\nDA:1,1\nDA:2,0\nend_of_record',
        );
        final failure = CoverdeCheckCoverageBelowMinimumFailure(
          minimumCoverage: 75,
          traceFile: traceFile,
        );

        final result = failure.actualCoverage;

        expect(result, traceFile.lineRate);
      });

      test('traceFile '
          '| returns the trace file', () {
        final traceFile = CoverageDocument.parse(
          'SF:path/to/file.dart\nDA:1,1\nend_of_record',
        );
        final failure = CoverdeCheckCoverageBelowMinimumFailure(
          minimumCoverage: 75,
          traceFile: traceFile,
        );

        final result = failure.traceFile;

        expect(result, traceFile);
      });
    });
  });
}
