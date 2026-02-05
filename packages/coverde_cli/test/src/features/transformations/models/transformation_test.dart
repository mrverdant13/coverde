import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
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
            '${Glob('**/*.dart', context: p.posix).pattern}',
          );
          expect(
            transformation,
            KeepByGlobTransformation(Glob('**/*.dart', context: p.posix)),
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
            '${Glob('**/*.dart', context: p.posix).pattern}',
          );
          expect(
            transformation,
            SkipByGlobTransformation(Glob('**/*.dart', context: p.posix)),
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

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage is below 0', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByCoverageTransformation.identifier}=eq|-5',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage is above 100', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByCoverageTransformation.identifier}=eq|150',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage range has invalid bounds', () {
          expect(
            () => Transformation.fromCliOption(
              '${KeepByCoverageTransformation.identifier}=in|[-10,110)',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
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

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage is below 0', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByCoverageTransformation.identifier}=eq|-5',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage is above 100', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByCoverageTransformation.identifier}=eq|150',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$TransformationFromCliOptionInvalidCoveragePercentageFailure '
            'when coverage percentage range has invalid bounds', () {
          expect(
            () => Transformation.fromCliOption(
              '${SkipByCoverageTransformation.identifier}=in|[-10,110)',
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<TransformationFromCliOptionInvalidCoveragePercentageFailure>(),
            ),
          );
        });
      });

      group('identifier: ${RelativeTransformation.identifier}', () {
        test('| returns $RelativeTransformation', () {
          final transformation = Transformation.fromCliOption(
            '${RelativeTransformation.identifier}='
            '${p.join('packages', 'app')}',
          );
          expect(
            transformation,
            RelativeTransformation(p.join('packages', 'app')),
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
          final t = RelativeTransformation(p.join('packages', 'app'));
          expect(t.describe, 'relative base-path=packages${p.separator}app');
        });
      });

      group('basePath', () {
        test('| returns the base path', () {
          final basePath = p.join('packages', 'apps');
          final t = RelativeTransformation(basePath);
          expect(t.basePath, basePath);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          final subject = RelativeTransformation(p.join('packages', 'app'));
          final same = RelativeTransformation(p.join('packages', 'app'));
          final other = RelativeTransformation(p.join('packages', 'apps'));
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });
  });
}
