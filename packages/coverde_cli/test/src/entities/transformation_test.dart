import 'package:coverde/src/entities/transformation.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Transformation', () {
    group('$KeepByRegexTransformation', () {
      test('describe | returns expected format', () {
        final t = KeepByRegexTransformation(RegExp('lib/.*'));
        expect(t.describe, 'keep-by-regex lib/.*');
      });

      test('regex | returns the regex pattern', () {
        final regex = RegExp(r'test/.*\.dart');
        final t = KeepByRegexTransformation(regex);
        expect(t.regex, regex);
      });

      test('flattenedSteps | returns single step', () {
        final t = KeepByRegexTransformation(RegExp('lib/.*'));
        expect(t.flattenedSteps.toList(), [t]);
      });
    });

    group('$SkipByRegexTransformation', () {
      test('describe | returns expected format', () {
        final t = SkipByRegexTransformation(RegExp(r'\.g\.dart$'));
        expect(t.describe, r'skip-by-regex \.g\.dart$');
      });

      test('regex | returns the regex pattern', () {
        final regex = RegExp('ignored');
        final t = SkipByRegexTransformation(regex);
        expect(t.regex, regex);
      });
    });

    group('$KeepByGlobTransformation', () {
      test('describe | returns expected format', () {
        final t = KeepByGlobTransformation(Glob('**/*.dart'));
        expect(t.describe, 'keep-by-glob **/*.dart');
      });

      test('glob | returns the glob pattern', () {
        final glob = Glob('lib/**/*.dart');
        final t = KeepByGlobTransformation(glob);
        expect(t.glob, glob);
      });
    });

    group('$SkipByGlobTransformation', () {
      test('describe | returns expected format', () {
        final t = SkipByGlobTransformation(Glob('**/*.g.dart'));
        expect(t.describe, 'skip-by-glob **/*.g.dart');
      });

      test('glob | returns the glob pattern', () {
        final glob = Glob('**/*.freezed.dart');
        final t = SkipByGlobTransformation(glob);
        expect(t.glob, glob);
      });
    });

    group('$RelativeTransformation', () {
      test('describe | returns expected format', () {
        final t = RelativeTransformation(path.join('packages', 'app'));
        expect(t.describe, 'relative base-path=packages${path.separator}app');
      });

      test('basePath | returns the base path', () {
        final basePath = path.join('packages', 'apps');
        final t = RelativeTransformation(basePath);
        expect(t.basePath, basePath);
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
        final keep = KeepByRegexTransformation(RegExp('lib/.*'));
        final preset = PresetTransformation(
          presetName: 'p',
          steps: [keep],
        );
        expect(preset.flattenedSteps.toList(), [keep]);
      });

      test('flattenedSteps | flattens nested presets', () {
        final skip = SkipByGlobTransformation(Glob('**/*.g.dart'));
        final inner = PresetTransformation(
          presetName: 'inner',
          steps: [skip],
        );
        final outer = PresetTransformation(
          presetName: 'outer',
          steps: [inner],
        );
        expect(outer.flattenedSteps.toList(), [skip]);
      });

      test(
        'stepsWithPresetChains | yields leaf with single preset in chain',
        () {
          final keep = KeepByRegexTransformation(RegExp('lib/.*'));
          final preset = PresetTransformation(
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
        final relative = RelativeTransformation(path.join('lib', ''));
        final inner = PresetTransformation(
          presetName: 'inner-preset',
          steps: [relative],
        );
        final outer = PresetTransformation(
          presetName: 'outer-preset',
          steps: [inner],
        );
        final pairs = outer.stepsWithPresetChains().toList();
        expect(pairs.length, 1);
        expect(pairs[0].presets, ['outer-preset', 'inner-preset']);
        expect(pairs[0].transformation, relative);
      });

      test('stepsWithPresetChains | chain joins with presetChainSeparator', () {
        final step = SkipByGlobTransformation(Glob('**/*.g.dart'));
        final inner = PresetTransformation(
          presetName: 'preset-a',
          steps: [step],
        );
        final outer = PresetTransformation(
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
