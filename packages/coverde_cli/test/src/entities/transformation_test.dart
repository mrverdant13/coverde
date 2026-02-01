import 'package:coverde/src/entities/transformation.dart';
import 'package:test/test.dart';

void main() {
  group('Transformation', () {
    group('$KeepByRegexTransformation', () {
      test('describe | returns expected format', () {
        const t = KeepByRegexTransformation('lib/.*', null);
        expect(t.describe, 'keep-by-regex lib/.*');
      });

      test('regex | returns the regex pattern', () {
        const t = KeepByRegexTransformation(r'test/.*\.dart', null);
        expect(t.regex, r'test/.*\.dart');
      });

      group('fromPreset', () {
        test('| returns null when not from preset', () {
          const t = KeepByRegexTransformation('lib/.*', null);
          expect(t.fromPreset, isNull);
        });

        test('| returns preset name when from preset', () {
          const t = KeepByRegexTransformation('lib/.*', 'my-preset');
          expect(t.fromPreset, 'my-preset');
        });
      });

      group('copyWith', () {
        test('| preserves regex when fromPreset is not provided', () {
          const t = KeepByRegexTransformation('lib/.*', 'preset');
          final copy = t.copyWith() as KeepByRegexTransformation;
          expect(copy.regex, 'lib/.*');
          expect(copy.fromPreset, 'preset');
        });

        test('| updates fromPreset when provided', () {
          const t = KeepByRegexTransformation('lib/.*', null);
          final copy =
              t.copyWith(fromPreset: 'new-preset') as KeepByRegexTransformation;
          expect(copy.regex, 'lib/.*');
          expect(copy.fromPreset, 'new-preset');
        });
      });
    });

    group('$SkipByRegexTransformation', () {
      test('describe | returns expected format', () {
        const t = SkipByRegexTransformation(r'\.g\.dart$', null);
        expect(t.describe, r'skip-by-regex \.g\.dart$');
      });

      test('regex | returns the regex pattern', () {
        const t = SkipByRegexTransformation('ignored', null);
        expect(t.regex, 'ignored');
      });

      test('copyWith | preserves regex and updates fromPreset', () {
        const t = SkipByRegexTransformation('foo', 'p');
        final copy = t.copyWith(fromPreset: 'q') as SkipByRegexTransformation;
        expect(copy.regex, 'foo');
        expect(copy.fromPreset, 'q');
      });
    });

    group('$KeepByGlobTransformation', () {
      test('describe | returns expected format', () {
        const t = KeepByGlobTransformation('**/*.dart', null);
        expect(t.describe, 'keep-by-glob **/*.dart');
      });

      test('glob | returns the glob pattern', () {
        const t = KeepByGlobTransformation('lib/**/*.dart', null);
        expect(t.glob, 'lib/**/*.dart');
      });

      test('copyWith | preserves glob when fromPreset is not provided', () {
        const t = KeepByGlobTransformation('**/*.dart', 'preset');
        final copy = t.copyWith() as KeepByGlobTransformation;
        expect(copy.glob, '**/*.dart');
        expect(copy.fromPreset, 'preset');
      });
    });

    group('$SkipByGlobTransformation', () {
      test('describe | returns expected format', () {
        const t = SkipByGlobTransformation('**/*.g.dart', null);
        expect(t.describe, 'skip-by-glob **/*.g.dart');
      });

      test('glob | returns the glob pattern', () {
        const t = SkipByGlobTransformation('**/*.freezed.dart', null);
        expect(t.glob, '**/*.freezed.dart');
      });

      test('copyWith | preserves glob and updates fromPreset', () {
        const t = SkipByGlobTransformation('**/*.g.dart', null);
        final copy =
            t.copyWith(fromPreset: 'dart-preset') as SkipByGlobTransformation;
        expect(copy.glob, '**/*.g.dart');
        expect(copy.fromPreset, 'dart-preset');
      });
    });

    group('$RelativeTransformation', () {
      test('describe | returns expected format', () {
        const t = RelativeTransformation('packages/app/', null);
        expect(t.describe, 'relative base-path=packages/app/');
      });

      test('basePath | returns the base path', () {
        const t = RelativeTransformation('packages/apps/', null);
        expect(t.basePath, 'packages/apps/');
      });

      test('fromPreset | returns preset name when from preset', () {
        const t = RelativeTransformation('lib/', 'relative-preset');
        expect(t.fromPreset, 'relative-preset');
      });

      group('copyWith', () {
        test('| preserves basePath when fromPreset is not provided', () {
          const t = RelativeTransformation('packages/', 'p');
          final copy = t.copyWith() as RelativeTransformation;
          expect(copy.basePath, 'packages/');
          expect(copy.fromPreset, 'p');
        });

        test('| updates fromPreset when provided', () {
          const t = RelativeTransformation('packages/', null);
          final copy =
              t.copyWith(fromPreset: 'my-preset') as RelativeTransformation;
          expect(copy.basePath, 'packages/');
          expect(copy.fromPreset, 'my-preset');
        });
      });
    });
  });
}
