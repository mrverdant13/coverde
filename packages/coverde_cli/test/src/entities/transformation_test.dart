import 'package:coverde/src/entities/transformation.dart';
import 'package:test/test.dart';

void main() {
  group('Transformation', () {
    group('$KeepByRegexTransformation', () {
      test('describe | returns expected format', () {
        const t = KeepByRegexTransformation('lib/.*');
        expect(t.describe, 'keep-by-regex lib/.*');
      });

      test('regex | returns the regex pattern', () {
        const t = KeepByRegexTransformation(r'test/.*\.dart');
        expect(t.regex, r'test/.*\.dart');
      });

      test('flattenedSteps | returns single step', () {
        const t = KeepByRegexTransformation('lib/.*');
        expect(t.flattenedSteps.toList(), [t]);
      });
    });

    group('$SkipByRegexTransformation', () {
      test('describe | returns expected format', () {
        const t = SkipByRegexTransformation(r'\.g\.dart$');
        expect(t.describe, r'skip-by-regex \.g\.dart$');
      });

      test('regex | returns the regex pattern', () {
        const t = SkipByRegexTransformation('ignored');
        expect(t.regex, 'ignored');
      });
    });

    group('$KeepByGlobTransformation', () {
      test('describe | returns expected format', () {
        const t = KeepByGlobTransformation('**/*.dart');
        expect(t.describe, 'keep-by-glob **/*.dart');
      });

      test('glob | returns the glob pattern', () {
        const t = KeepByGlobTransformation('lib/**/*.dart');
        expect(t.glob, 'lib/**/*.dart');
      });
    });

    group('$SkipByGlobTransformation', () {
      test('describe | returns expected format', () {
        const t = SkipByGlobTransformation('**/*.g.dart');
        expect(t.describe, 'skip-by-glob **/*.g.dart');
      });

      test('glob | returns the glob pattern', () {
        const t = SkipByGlobTransformation('**/*.freezed.dart');
        expect(t.glob, '**/*.freezed.dart');
      });
    });

    group('$RelativeTransformation', () {
      test('describe | returns expected format', () {
        const t = RelativeTransformation('packages/app/');
        expect(t.describe, 'relative base-path=packages/app/');
      });

      test('basePath | returns the base path', () {
        const t = RelativeTransformation('packages/apps/');
        expect(t.basePath, 'packages/apps/');
      });
    });

    group('$PresetTransformation', () {
      test('describe | returns preset name', () {
        const t = PresetTransformation(
          presetName: 'my-preset',
          steps: [],
        );
        expect(t.describe, 'preset my-preset');
      });

      test('flattenedSteps | returns inner steps only', () {
        const keep = KeepByRegexTransformation('lib/.*');
        const preset = PresetTransformation(
          presetName: 'p',
          steps: [keep],
        );
        expect(preset.flattenedSteps.toList(), [keep]);
      });

      test('flattenedSteps | flattens nested presets', () {
        const skip = SkipByGlobTransformation('**/*.g.dart');
        const inner = PresetTransformation(
          presetName: 'inner',
          steps: [skip],
        );
        const outer = PresetTransformation(
          presetName: 'outer',
          steps: [inner],
        );
        expect(outer.flattenedSteps.toList(), [skip]);
      });

      test(
        'stepsWithPresetChains | yields leaf with single preset in chain',
        () {
          const keep = KeepByRegexTransformation('lib/.*');
          const preset = PresetTransformation(
            presetName: 'some-preset',
            steps: [keep],
          );
          final pairs = preset.stepsWithPresetChains().toList();
          expect(pairs.length, 1);
          expect(pairs[0].presets, ['some-preset']);
          expect(pairs[0].transformation, keep);
        },
      );

      test('stepsWithPresetChains | yields leaf with nested preset chain', () {
        const relative = RelativeTransformation('lib/');
        const inner = PresetTransformation(
          presetName: 'inner-preset',
          steps: [relative],
        );
        const outer = PresetTransformation(
          presetName: 'outer-preset',
          steps: [inner],
        );
        final pairs = outer.stepsWithPresetChains().toList();
        expect(pairs.length, 1);
        expect(pairs[0].presets, ['outer-preset', 'inner-preset']);
        expect(pairs[0].transformation, relative);
      });

      test('stepsWithPresetChains | chain joins with presetChainSeparator', () {
        const step = SkipByGlobTransformation('**/*.g.dart');
        const inner = PresetTransformation(
          presetName: 'preset-a',
          steps: [step],
        );
        const outer = PresetTransformation(
          presetName: 'preset-b',
          steps: [inner],
        );
        final (:presets, :transformation) =
            outer.stepsWithPresetChains().single;
        expect(presets.join(presetChainSeparator), 'preset-b → preset-a');
      });
    });
  });
}
