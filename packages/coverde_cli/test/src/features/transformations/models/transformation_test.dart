import 'package:collection/collection.dart';
import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('$Transformation', () {
    group('fromCliOption', () {
      group('identifier: ${KeepByRegexTransformation.identifier}', () {
        test('| returns $KeepByRegexTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${KeepByRegexTransformation.identifier}='
            '${RegExp('lib/.*').pattern}',
          );
          expect(
            transformation,
            KeepByRegexTransformation(RegExp('lib/.*')),
          );
        });

        test(
            '| throws $TransformationFromCliOptionInvalidRegexPatternFailure '
            'when invalid regex pattern', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByRegexTransformation.identifier}=[invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidRegexPatternFailure>(),
            ),
          );
        });
      });

      group('identifier: ${SkipByRegexTransformation.identifier}', () {
        test('| returns $SkipByRegexTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${SkipByRegexTransformation.identifier}='
            '${RegExp('lib/.*').pattern}',
          );
          expect(
            transformation,
            SkipByRegexTransformation(RegExp('lib/.*')),
          );
        });

        test(
            '| throws $TransformationFromCliOptionInvalidRegexPatternFailure '
            'when invalid regex pattern', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByRegexTransformation.identifier}=[invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidRegexPatternFailure>(),
            ),
          );
        });
      });

      group('identifier: ${KeepByGlobTransformation.identifier}', () {
        test('| returns $KeepByGlobTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${KeepByGlobTransformation.identifier}='
            '${Glob('**/*.dart').pattern}',
          );
          expect(
            transformation,
            KeepByGlobTransformation(Glob('**/*.dart')),
          );
        });

        test(
            '| throws $TransformationFromCliOptionInvalidGlobPatternFailure '
            'when invalid glob pattern', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByGlobTransformation.identifier}=[invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidGlobPatternFailure>(),
            ),
          );
        });
      });

      group('identifier: ${SkipByGlobTransformation.identifier}', () {
        test('| returns $SkipByGlobTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${SkipByGlobTransformation.identifier}='
            '${Glob('**/*.dart').pattern}',
          );
          expect(
            transformation,
            SkipByGlobTransformation(Glob('**/*.dart')),
          );
        });

        test(
            '| throws $TransformationFromCliOptionInvalidGlobPatternFailure '
            'when invalid glob pattern', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByGlobTransformation.identifier}=[invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidGlobPatternFailure>(),
            ),
          );
        });
      });

      group('identifier: ${KeepByCoverageTransformation.identifier}', () {
        test('| returns $KeepByCoverageTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${KeepByCoverageTransformation.identifier}='
            '${const EqualsNumericComparison(reference: 0.5).describe}',
          );
          expect(
            transformation,
            const KeepByCoverageTransformation(
              comparison: EqualsNumericComparison(reference: 0.5),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidNumericComparisonFailure '
            'when invalid numeric comparison description', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByCoverageTransformation.identifier}=invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidNumericComparisonFailure>(),
            ),
          );
        });
      });

      group('identifier: ${SkipByCoverageTransformation.identifier}', () {
        test('| returns $SkipByCoverageTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${SkipByCoverageTransformation.identifier}='
            '${const EqualsNumericComparison(reference: 0.5).describe}',
          );
          expect(
            transformation,
            const SkipByCoverageTransformation(
              comparison: EqualsNumericComparison(reference: 0.5),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidNumericComparisonFailure '
            'when invalid numeric comparison description', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByCoverageTransformation.identifier}=invalid',
            ),
            throwsA(
              isA<TransformationFromCliOptionInvalidNumericComparisonFailure>(),
            ),
          );
        });
      });

      group('identifier: ${RelativeTransformation.identifier}', () {
        test('| returns $RelativeTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${RelativeTransformation.identifier}='
            '${path.join('packages', 'app')}',
          );
          expect(
            transformation,
            RelativeTransformation(path.join('packages', 'app')),
          );
        });
      });

      group('identifier: ${PresetTransformation.identifier}', () {
        test('| returns $PresetTransformation', () {
          const preset = PresetTransformation(
            presetName: 'my-preset',
            steps: [],
          );
          final transformation = Transformation.fromCliOption(
            '${PresetTransformation.identifier}=my-preset',
            presets: const [preset],
          );
          expect(
            transformation,
            preset,
          );
        });

        test(
            '| throws $TransformationFromCliOptionUnknownPresetFailure '
            'when unknown preset', () {
          expect(
            () => Transformation.fromCliOption(
              '${PresetTransformation.identifier}=unknown',
            ),
            throwsA(isA<TransformationFromCliOptionUnknownPresetFailure>()),
          );
        });
      });

      test(
          '| throws '
          '$TransformationFromCliOptionUnsupportedTransformationFailure '
          'when unsupported transformation', () {
        expect(
          () => Transformation.fromCliOption('unknown'),
          throwsA(
            isA<TransformationFromCliOptionUnsupportedTransformationFailure>(),
          ),
        );
      });
    });

    group('$PresetTransformation', () {
      group('describe', () {
        test('| returns description', () {
          const t = PresetTransformation(
            presetName: 'my-preset',
            steps: [],
          );
          expect(t.describe, 'preset name=my-preset');
        });
      });

      group('presetName', () {
        test('| returns the preset name', () {
          const t = PresetTransformation(
            presetName: 'my-preset',
            steps: [],
          );
          expect(t.presetName, 'my-preset');
        });
      });

      group('steps', () {
        test('| returns the steps', () {
          final step1 = KeepByRegexTransformation(RegExp('lib/.*'));
          final step2 = SkipByGlobTransformation(Glob('**/*.g.dart'));
          final t = PresetTransformation(
            presetName: 'my-preset',
            steps: [step1, step2],
          );
          expect(t.steps, [step1, step2]);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = PresetTransformation(
            presetName: 'my-preset',
            steps: [KeepByRegexTransformation(RegExp('lib/.*'))],
          );
          final same = PresetTransformation(
            presetName: 'my-preset',
            steps: [KeepByRegexTransformation(RegExp('lib/.*'))],
          );
          final other = PresetTransformation(
            presetName: 'my-preset',
            steps: [KeepByRegexTransformation(RegExp('test/.*'))],
          );
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$KeepByRegexTransformation', () {
      group('describe', () {
        test('| returns description', () {
          final t = KeepByRegexTransformation(RegExp('lib/.*'));
          expect(t.describe, 'keep-by-regex pattern=lib/.*');
        });
      });

      group('regex', () {
        test('| returns the regex pattern', () {
          final regex = RegExp(r'test/.*\.dart');
          final t = KeepByRegexTransformation(regex);
          expect(t.regex, regex);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = KeepByRegexTransformation(RegExp('lib/.*'));
          final same = KeepByRegexTransformation(RegExp('lib/.*'));
          final other = KeepByRegexTransformation(RegExp('test/.*'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$SkipByRegexTransformation', () {
      group('describe', () {
        test('| returns description', () {
          final t = SkipByRegexTransformation(RegExp(r'\.g\.dart$'));
          expect(t.describe, r'skip-by-regex pattern=\.g\.dart$');
        });
      });

      group('regex', () {
        test('| returns the regex pattern', () {
          final regex = RegExp('ignored');
          final t = SkipByRegexTransformation(regex);
          expect(t.regex, regex);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = SkipByRegexTransformation(RegExp(r'\.g\.dart$'));
          final same = SkipByRegexTransformation(RegExp(r'\.g\.dart$'));
          final other = SkipByRegexTransformation(RegExp(r'\.g\.dart'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$KeepByGlobTransformation', () {
      group('describe', () {
        test('| returns description', () {
          final t = KeepByGlobTransformation(Glob('**/*.dart'));
          expect(t.describe, 'keep-by-glob pattern=**/*.dart');
        });
      });

      group('glob', () {
        test('| returns the glob pattern', () {
          final glob = Glob('lib/**/*.dart');
          final t = KeepByGlobTransformation(glob);
          expect(t.glob, glob);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = KeepByGlobTransformation(Glob('**/*.dart'));
          final same = KeepByGlobTransformation(Glob('**/*.dart'));
          final other = KeepByGlobTransformation(Glob('**/*.g.dart'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$SkipByGlobTransformation', () {
      group('describe', () {
        test('| returns description', () {
          final t = SkipByGlobTransformation(Glob('**/*.g.dart'));
          expect(t.describe, 'skip-by-glob pattern=**/*.g.dart');
        });
      });

      group('glob', () {
        test('| returns the glob pattern', () {
          final glob = Glob('**/*.freezed.dart');
          final t = SkipByGlobTransformation(glob);
          expect(t.glob, glob);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = SkipByGlobTransformation(Glob('**/*.g.dart'));
          final same = SkipByGlobTransformation(Glob('**/*.g.dart'));
          final other = SkipByGlobTransformation(Glob('**/*.freezed.dart'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$KeepByCoverageTransformation', () {
      group('describe', () {
        test('| returns description', () {
          const t = KeepByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          expect(t.describe, 'keep-by-coverage comparison=eq|0.5');
        });
      });

      group('comparison', () {
        test('| returns the comparison', () {
          const comparison = EqualsNumericComparison(reference: 0.5);
          const t = KeepByCoverageTransformation(comparison: comparison);
          expect(t.comparison, comparison);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = KeepByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          const same = KeepByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          const other = KeepByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.6),
          );
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$SkipByCoverageTransformation', () {
      group('describe', () {
        test('| returns description', () {
          const t = SkipByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          expect(t.describe, 'skip-by-coverage comparison=eq|0.5');
        });
      });

      group('comparison', () {
        test('| returns the comparison', () {
          const comparison = EqualsNumericComparison(reference: 0.5);
          const t = SkipByCoverageTransformation(comparison: comparison);
          expect(t.comparison, comparison);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = SkipByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          const same = SkipByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.5),
          );
          const other = SkipByCoverageTransformation(
            comparison: EqualsNumericComparison(reference: 0.6),
          );
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$RelativeTransformation', () {
      group('describe', () {
        test('| returns description', () {
          final t = RelativeTransformation(path.join('packages', 'app'));
          expect(t.describe, 'relative base-path=packages${path.separator}app');
        });
      });

      group('basePath', () {
        test('| returns the base path', () {
          final basePath = path.join('packages', 'apps');
          final t = RelativeTransformation(basePath);
          expect(t.basePath, basePath);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = RelativeTransformation(path.join('packages', 'app'));
          final same = RelativeTransformation(path.join('packages', 'app'));
          final other = RelativeTransformation(path.join('packages', 'apps'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });
  });

  group('$Transformations', () {
    group('flattenedSteps', () {
      test('| returns the flattened steps', () {
        final step_1_1 = KeepByRegexTransformation(RegExp('lib/.*'));
        final step_1_2 = SkipByGlobTransformation(Glob('**/*.g.dart'));
        final step_1 = PresetTransformation(
          presetName: 'my-preset',
          steps: [
            step_1_1,
            step_1_2,
          ],
        );
        final step_2 = KeepByRegexTransformation(RegExp('test/.*'));
        final steps = [step_1, step_2];
        expect(steps.flattenedSteps, [step_1_1, step_1_2, step_2]);
      });
    });

    group('getStepsWithPresetChains', () {
      test('| returns the steps with preset chains', () {
        final step_1_1 = KeepByRegexTransformation(RegExp('lib/.*'));
        final step_1_2 = SkipByGlobTransformation(Glob('**/*.g.dart'));
        final step_1 = PresetTransformation(
          presetName: 'some-preset',
          steps: [
            step_1_1,
            step_1_2,
          ],
        );
        final step_2 = KeepByRegexTransformation(RegExp('test/.*'));
        final step_3_1 = KeepByRegexTransformation(RegExp('test/.*'));
        final step_3_2_1 = SkipByRegexTransformation(RegExp('test/.*'));
        final step_3_2_2 = SkipByGlobTransformation(Glob('**/*.freezed.dart'));
        final step_3_2 = PresetTransformation(
          presetName: 'some-nested-preset',
          steps: [
            step_3_2_1,
            step_3_2_2,
          ],
        );
        final step_3_3 = SkipByGlobTransformation(Glob('**/*.freezed.dart'));
        final step_3 = PresetTransformation(
          presetName: 'some-other-preset',
          steps: [
            step_3_1,
            step_3_2,
            step_3_3,
          ],
        );
        final steps = [
          step_1,
          step_2,
          step_3,
        ];
        final result = steps.getStepsWithPresetChains().toList();
        const presetsEquality = ListEquality<String>();
        expect(
          result,
          pairwiseCompare<LeafTransformationWithPresetChains,
              LeafTransformationWithPresetChains>(
            [
              (
                transformation: step_1_1,
                presets: ['some-preset'],
              ),
              (
                transformation: step_1_2,
                presets: ['some-preset'],
              ),
              (
                transformation: step_2,
                presets: <String>[],
              ),
              (
                transformation: step_3_1,
                presets: ['some-other-preset'],
              ),
              (
                transformation: step_3_2_1,
                presets: ['some-other-preset', 'some-nested-preset']
              ),
              (
                transformation: step_3_2_2,
                presets: ['some-other-preset', 'some-nested-preset']
              ),
              (
                transformation: step_3_3,
                presets: ['some-other-preset'],
              ),
            ],
            (a, b) =>
                a.transformation == b.transformation &&
                presetsEquality.equals(a.presets, b.presets),
            'transformations and presets',
          ),
        );
      });
    });
  });
}
