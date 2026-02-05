import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:glob/glob.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeConfig', () {
    test('| can be instantiated', () {
      const config = CoverdeConfig(presets: []);
      expect(config, isA<CoverdeConfig>());
    });

    group('fromYaml', () {
      test('| returns $CoverdeConfig', () {
        const yamlString = '''
        transformations:
          preset-1:
            - type: keep-by-regex
              regex: lib/.*
          preset-2:
            - type: keep-by-regex
              regex: test/.*
        ''';
        final config = CoverdeConfig.fromYaml(yamlString);
        expect(config, isA<CoverdeConfig>());
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlFailure '
          'when YAML string is invalid', () {
        const yamlString = 'invalid: [yaml';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML root is not a map', () {
        const yamlString = '- transformations: 123';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      test('| returns $CoverdeConfig even without transformations member', () {
        const yamlString = 'presets: [preset-1, preset-2]';
        final config = CoverdeConfig.fromYaml(yamlString);
        expect(config, isA<CoverdeConfig>());
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML transformation presets member is not a map', () {
        const yamlString = 'transformations: 123';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML transformation preset name is not a string', () {
        const yamlString = '''
        transformations:
          123:
            - type: keep-by-regex
              regex: lib/.*
        ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML transformation preset steps are not a list', () {
        const yamlString = '''
        transformations:
          preset: 123
        ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML transformation preset step is not a map', () {
        const yamlString = '''
        transformations:
          preset:
            - 123
        ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
          'when YAML transformation preset step type is not a string', () {
        const yamlString = '''
        transformations:
          preset:
            - type: 123
        ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
        );
      });

      group('identifier: ${KeepByRegexTransformation.identifier}', () {
        test('| returns $KeepByRegexTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-regex
                regex: lib/.*
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    KeepByRegexTransformation(RegExp('lib/.*')),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step regex is not a string', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-regex
                regex: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step regex '
            'is not a valid regex pattern', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-regex
                regex: '[invalid'
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${SkipByRegexTransformation.identifier}', () {
        test('| returns $SkipByRegexTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-regex
                regex: lib/.*
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    SkipByRegexTransformation(RegExp('lib/.*')),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step regex is not a string', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-regex
                regex: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step regex '
            'is not a valid regex pattern', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-regex
                regex: '[invalid'
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${KeepByGlobTransformation.identifier}', () {
        test('| returns $KeepByGlobTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-glob
                glob: lib/**/*.dart
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    KeepByGlobTransformation(Glob('lib/**/*.dart')),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step glob is not a string', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-glob
                glob: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step glob '
            'is not a valid glob pattern', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-glob
                glob: '[invalid'
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${SkipByGlobTransformation.identifier}', () {
        test('| returns $SkipByGlobTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-glob
                glob: lib/**/*.dart
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    SkipByGlobTransformation(Glob('lib/**/*.dart')),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step glob is not a string', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-glob
                glob: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step glob '
            'is not a valid glob pattern', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-glob
                glob: '[invalid'
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${KeepByCoverageTransformation.identifier}', () {
        test('| returns $KeepByCoverageTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-coverage
                comparison: eq|0.5
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            const CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    KeepByCoverageTransformation(
                      comparison: EqualsNumericComparison(reference: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step comparison is not a string',
            () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-coverage
                comparison: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step comparison '
            'is not a valid numeric comparison', () {
          const yamlString = '''
          transformations:
            preset:
              - type: keep-by-coverage
                comparison: invalid
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${SkipByCoverageTransformation.identifier}', () {
        test('| returns $SkipByCoverageTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-coverage
                comparison: eq|0.5
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            const CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    SkipByCoverageTransformation(
                      comparison: EqualsNumericComparison(reference: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step comparison is not a string',
            () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-coverage
                comparison: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
            'when YAML transformation preset step comparison '
            'is not a valid numeric comparison', () {
          const yamlString = '''
          transformations:
            preset:
              - type: skip-by-coverage
                comparison: invalid
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
          );
        });
      });

      group('identifier: ${RelativeTransformation.identifier}', () {
        test('| returns $RelativeTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: relative
                base-path: packages/app
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            const CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    RelativeTransformation('packages/app'),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset step base-path is not a string',
            () {
          const yamlString = '''
          transformations:
            preset:
              - type: relative
                base-path: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });
      });

      group('identifier: ${PresetTransformation.identifier}', () {
        test('| returns $PresetTransformation', () {
          const yamlString = '''
          transformations:
            preset:
              - type: preset
                name: nested-preset
            nested-preset:
              - type: keep-by-regex
                regex: lib/.*
              ''';
          final config = CoverdeConfig.fromYaml(yamlString);
          expect(
            config,
            CoverdeConfig(
              presets: [
                PresetTransformation(
                  presetName: 'preset',
                  steps: [
                    PresetTransformation(
                      presetName: 'nested-preset',
                      steps: [
                        KeepByRegexTransformation(RegExp('lib/.*')),
                      ],
                    ),
                  ],
                ),
                PresetTransformation(
                  presetName: 'nested-preset',
                  steps: [
                    KeepByRegexTransformation(RegExp('lib/.*')),
                  ],
                ),
              ],
            ),
          );
        });

        test(
            '| throws $CoverdeConfigFromYamlInvalidYamlMemberTypeFailure '
            'when YAML transformation preset name is not a string', () {
          const yamlString = '''
          transformations:
            preset:
              - type: preset
                name: 123
          ''';
          expect(
            () => CoverdeConfig.fromYaml(yamlString),
            throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberTypeFailure>()),
          );
        });
      });

      test(
          '| throws $CoverdeConfigFromYamlInvalidYamlMemberValueFailure '
          'when YAML transformation preset step type is not a valid preset',
          () {
        const yamlString = '''
          transformations:
            preset:
              - type: invalid-step-type
                arg: something
          ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlInvalidYamlMemberValueFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlUnknownPresetFailure '
          'when YAML transformation preset step references an unknown preset',
          () {
        const yamlString = '''
          transformations:
            preset:
              - type: preset
                name: invalid-preset
          ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlUnknownPresetFailure>()),
        );
      });

      test(
          '| throws $CoverdeConfigFromYamlPresetCycleFailure '
          'when YAML transformation preset step references a preset that '
          'references the original preset', () {
        const yamlString = '''
          transformations:
            preset:
              - type: preset
                name: nested-preset
            nested-preset:
              - type: preset
                name: preset
          ''';
        expect(
          () => CoverdeConfig.fromYaml(yamlString),
          throwsA(isA<CoverdeConfigFromYamlPresetCycleFailure>()),
        );
      });
    });

    group('== & hashCode', () {
      test('| verifies equality and hash code resolution', () {
        const config = CoverdeConfig(presets: []);
        const same = CoverdeConfig(presets: []);
        const other = CoverdeConfig(
          presets: [
            PresetTransformation(presetName: 'preset-1', steps: []),
          ],
        );
        expect(config, same);
        expect(config, isNot(other));
        expect(config.hashCode, same.hashCode);
        expect(config.hashCode, isNot(other.hashCode));
      });
    });
  });
}
