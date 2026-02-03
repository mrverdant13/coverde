import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:glob/glob.dart';
import 'package:test/test.dart';

void main() {
  group('$PresetsParser', () {
    late PresetsParser parser;

    setUp(() {
      parser = PresetsParser();
    });

    group('parsePresetsFromRawConfig', () {
      test('returns empty list when config has no transformations key', () {
        final result = parser.parsePresetsFromRawConfig({});
        expect(result, isEmpty);
      });

      test('returns empty list when transformations is null', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': null,
        });
        expect(result, isEmpty);
      });

      test('returns empty list when transformations is empty map', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': <String, dynamic>{},
        });
        expect(result, isEmpty);
      });

      test('parses keep-by-regex step', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'my-preset': [
              {
                'type': 'keep-by-regex',
                'regex': 'lib/.*',
              },
            ],
          },
        });
        expect(result, hasLength(1));
        final preset = result.single;
        expect(preset.presetName, 'my-preset');
        final steps = preset.steps;
        expect(steps, hasLength(1));
        expect(
          steps.single,
          isA<KeepByRegexTransformation>().having(
            (e) => e.regex,
            'regex',
            RegExp('lib/.*'),
          ),
        );
      });

      test('parses skip-by-regex step', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'my-preset': [
              {
                'type': 'skip-by-regex',
                'regex': r'\.g\.dart$',
              },
            ],
          },
        });
        expect(result, hasLength(1));
        final preset = result.single;
        expect(preset.presetName, 'my-preset');
        final steps = preset.steps;
        expect(steps, hasLength(1));
        expect(
          steps.single,
          isA<SkipByRegexTransformation>().having(
            (e) => e.regex,
            'regex',
            RegExp(r'\.g\.dart$'),
          ),
        );
      });

      test('parses keep-by-glob step', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'my-preset': [
              {
                'type': 'keep-by-glob',
                'glob': '**/*.dart',
              },
            ],
          },
        });
        expect(result, hasLength(1));
        final preset = result.single;
        expect(preset.presetName, 'my-preset');
        final steps = preset.steps;
        expect(steps, hasLength(1));
        expect(
          steps.single,
          isA<KeepByGlobTransformation>().having(
            (e) => e.glob,
            'glob',
            isA<Glob>().having(
              (e) => e.pattern,
              'pattern',
              '**/*.dart',
            ),
          ),
        );
      });

      test('parses skip-by-glob step', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'my-preset': [
              {
                'type': 'skip-by-glob',
                'glob': '**/*.g.dart',
              },
            ],
          },
        });
        expect(result, hasLength(1));
        final preset = result.single;
        expect(preset.presetName, 'my-preset');
        final steps = preset.steps;
        expect(steps, hasLength(1));
        expect(
          steps.single,
          isA<SkipByGlobTransformation>().having(
            (e) => e.glob,
            'glob',
            isA<Glob>().having(
              (e) => e.pattern,
              'pattern',
              '**/*.g.dart',
            ),
          ),
        );
      });

      test('parses relative step', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'my-preset': [
              {
                'type': 'relative',
                'base-path': 'packages/app',
              },
            ],
          },
        });
        expect(result, hasLength(1));
        final preset = result.single;
        expect(preset.presetName, 'my-preset');
        final steps = preset.steps;
        expect(steps, hasLength(1));
        expect(
          steps.single,
          isA<RelativeTransformation>().having(
            (e) => e.basePath,
            'basePath',
            'packages/app',
          ),
        );
      });

      test('parses preset ref and expands nested preset', () {
        final result = parser.parsePresetsFromRawConfig({
          'transformations': {
            'outer': [
              {
                'type': 'preset',
                'name': 'inner',
              },
              {
                'type': 'keep-by-regex',
                'regex': 'lib/.*',
              },
            ],
            'inner': [
              {
                'type': 'skip-by-glob',
                'glob': '**/*.g.dart',
              },
            ],
          },
        });
        expect(result, hasLength(2));
        expect(
          result,
          containsAllInOrder([
            isA<PresetTransformation>()
                .having(
                  (e) => e.presetName,
                  'presetName',
                  'outer',
                )
                .having(
                  (e) => e.steps,
                  'steps',
                  hasLength(2),
                )
                .having(
                  (e) => e.steps,
                  'steps',
                  containsAllInOrder([
                    isA<PresetTransformation>().having(
                      (e) => e.presetName,
                      'presetName',
                      'inner',
                    ),
                    isA<KeepByRegexTransformation>().having(
                      (e) => e.regex,
                      'regex',
                      RegExp('lib/.*'),
                    ),
                  ]),
                ),
            isA<PresetTransformation>()
                .having(
                  (e) => e.presetName,
                  'presetName',
                  'inner',
                )
                .having(
                  (e) => e.steps,
                  'steps',
                  hasLength(1),
                )
                .having(
                  (e) => e.steps,
                  'steps',
                  containsAllInOrder([
                    isA<SkipByGlobTransformation>().having(
                      (e) => e.glob,
                      'glob',
                      isA<Glob>().having(
                        (e) => e.pattern,
                        'pattern',
                        '**/*.g.dart',
                      ),
                    ),
                  ]),
                ),
          ]),
        );
      });

      test(
          'throws $ParseRawPresetsInvalidRawPresetsMemberTypeFailure '
          'when transformations is not a $Map', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': <dynamic>[],
            });

        expect(
          action,
          throwsA(
            isA<ParseRawPresetsInvalidRawPresetsMemberTypeFailure>().having(
              (e) => e.key,
              'key',
              null,
            ),
          ),
        );
      });

      test(
          'throws $ParseRawPresetsInvalidRawPresetsMemberTypeFailure '
          'when preset name is not $String', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                123: <dynamic>[],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParseRawPresetsInvalidRawPresetsMemberTypeFailure>().having(
              (e) => e.key,
              'key',
              '[key=123]',
            ),
          ),
        );
      });

      test(
          'throws $ParseRawPresetsInvalidRawPresetsMemberTypeFailure '
          'when raw steps is not a $List', () {
        void action() => parser.parsePresetsFromRawConfig(<String, dynamic>{
              'transformations': <String, dynamic>{
                'preset': 'not-a-list',
              },
            });

        expect(
          action,
          throwsA(
            isA<ParseRawPresetsInvalidRawPresetsMemberTypeFailure>().having(
              (e) => e.key,
              'key',
              '[key=preset]',
            ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when step is not a $Map', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': ['not-a-map'],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0]',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  Map,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when type is not $String', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 123,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].type',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when regex is not a $String for $KeepByRegexTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'keep-by-regex',
                    'regex': 123,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].regex',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  123,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberValueFailure '
          'when regex is invalid for $KeepByRegexTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'keep-by-regex',
                    'regex': '[invalid',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberValueFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].regex',
                )
                .having(
                  (e) => e.value,
                  'value',
                  '[invalid',
                )
                .having(
                  (e) => e.hint,
                  'hint',
                  'a valid regex pattern',
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when regex is not a $String for $SkipByRegexTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'skip-by-regex',
                    'regex': 123,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].regex',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  123,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberValueFailure '
          'when regex is invalid for $SkipByRegexTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'skip-by-regex',
                    'regex': '[invalid',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberValueFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].regex',
                )
                .having(
                  (e) => e.value,
                  'value',
                  '[invalid',
                )
                .having(
                  (e) => e.hint,
                  'hint',
                  'a valid regex pattern',
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when glob is not a $String for $KeepByGlobTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'keep-by-glob',
                    'glob': 123,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].glob',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  123,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberValueFailure '
          'when glob is invalid for $KeepByGlobTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'keep-by-glob',
                    'glob': '**[invalid',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberValueFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].glob',
                )
                .having(
                  (e) => e.value,
                  'value',
                  '**[invalid',
                )
                .having(
                  (e) => e.hint,
                  'hint',
                  'a valid glob pattern',
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when glob is not a $String for $SkipByGlobTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'skip-by-glob',
                    'glob': 123,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].glob',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  123,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberValueFailure '
          'when glob is invalid for $SkipByGlobTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'skip-by-glob',
                    'glob': '**[invalid',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberValueFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].glob',
                )
                .having(
                  (e) => e.value,
                  'value',
                  '**[invalid',
                )
                .having(
                  (e) => e.hint,
                  'hint',
                  'a valid glob pattern',
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when base-path is not $String for $RelativeTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'relative',
                    'base-path': 456,
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].base-path',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  456,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberTypeFailure '
          'when name is not $String for $PresetTransformation', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'preset',
                    'name': 123,
                  },
                ],
              },
            });
        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberTypeFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].name',
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  String,
                )
                .having(
                  (e) => e.value,
                  'value',
                  123,
                ),
          ),
        );
      });

      test(
          'throws $ParsePresetStepsInvalidRawPresetStepMemberValueFailure '
          'when type is unknown', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'unknown-type',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ParsePresetStepsInvalidRawPresetStepMemberValueFailure>()
                .having(
                  (e) => e.key,
                  'key',
                  '[key=preset].[0].type',
                )
                .having(
                  (e) => e.value,
                  'value',
                  'unknown-type',
                )
                .having(
                  (e) => e.hint,
                  'hint',
                  'one of: '
                      'keep-by-regex, '
                      'skip-by-regex, '
                      'keep-by-glob, '
                      'skip-by-glob, '
                      'relative, '
                      'preset',
                ),
          ),
        );
      });

      test(
          'throws $ExpandPresetUnknownPresetFailure '
          'when preset references unknown preset', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset': [
                  {
                    'type': 'preset',
                    'name': 'missing',
                  },
                ],
                'other': <dynamic>[],
              },
            });

        expect(
          action,
          throwsA(
            isA<ExpandPresetUnknownPresetFailure>()
                .having(
                  (e) => e.unknownPreset,
                  'unknownPreset',
                  'missing',
                )
                .having(
                  (e) => e.availablePresets,
                  'availablePresets',
                  contains('other'),
                ),
          ),
        );
      });

      test(
          'throws $ExpandPresetPresetCycleFailure '
          'when presets have cycle', () {
        void action() => parser.parsePresetsFromRawConfig({
              'transformations': {
                'preset-a': [
                  {
                    'type': 'preset',
                    'name': 'preset-b',
                  },
                ],
                'preset-b': [
                  {
                    'type': 'preset',
                    'name': 'preset-a',
                  },
                ],
              },
            });

        expect(
          action,
          throwsA(
            isA<ExpandPresetPresetCycleFailure>().having(
              (e) => e.cycle,
              'cycle',
              ['preset-a', 'preset-b', 'preset-a'],
            ),
          ),
        );
      });
    });
  });
}
