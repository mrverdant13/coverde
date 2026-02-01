import 'package:meta/meta.dart';

/// Separator used when showing nested preset hierarchy (e.g. "preset-a →
/// preset-b").
const String presetChainSeparator = ' → ';

/// {@template transformation}
/// A transformation step to apply to coverage trace file paths.
/// {@endtemplate}
@immutable
sealed class Transformation {
  /// {@macro transformation}
  const Transformation();

  /// Human-readable description of this transformation.
  String get describe;

  /// Flattens this transformation to leaf steps only.
  ///
  /// [PresetTransformation] is expanded; leaf transformations return
  /// themselves.
  Iterable<Transformation> get flattenedSteps sync* {
    switch (this) {
      case PresetTransformation(:final steps):
        yield* steps.expand((s) => s.flattenedSteps);
      default:
        yield this;
    }
  }

  /// Yields each leaf step with its preset chain (outermost first).
  ///
  /// Used to show "from preset a → b" for nested presets.
  Iterable<
      ({
        List<String> presets,
        Transformation transformation,
      })> stepsWithPresetChains([
    List<String> precedingPresets = const [],
  ]) sync* {
    switch (this) {
      case PresetTransformation(:final presetName, :final steps):
        yield* steps.expand(
          (s) => s.stepsWithPresetChains([
            ...precedingPresets,
            presetName,
          ]),
        );
      default:
        yield (
          presets: precedingPresets,
          transformation: this,
        );
    }
  }
}

/// {@template preset_transformation}
/// Groups a set of transformations under a preset name (may include nested
/// [PresetTransformation]s).
/// {@endtemplate}
@immutable
final class PresetTransformation extends Transformation {
  /// {@macro preset_transformation}
  const PresetTransformation({
    required this.presetName,
    required this.steps,
  });

  /// The preset name.
  final String presetName;

  /// The transformations in this preset (may include nested
  /// [PresetTransformation]s).
  final List<Transformation> steps;

  @override
  String get describe => 'preset $presetName';
}

/// {@template keep_by_regex_transformation}
/// Keeps only files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class KeepByRegexTransformation extends Transformation {
  /// {@macro keep_by_regex_transformation}
  const KeepByRegexTransformation(this.regex);

  /// The regex pattern to match.
  final String regex;

  @override
  String get describe => 'keep-by-regex $regex';
}

/// {@template skip_by_regex_transformation}
/// Skips files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class SkipByRegexTransformation extends Transformation {
  /// {@macro skip_by_regex_transformation}
  const SkipByRegexTransformation(this.regex);

  /// The regex pattern to match.
  final String regex;

  @override
  String get describe => 'skip-by-regex $regex';
}

/// {@template keep_by_glob_transformation}
/// Keeps only files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class KeepByGlobTransformation extends Transformation {
  /// {@macro keep_by_glob_transformation}
  const KeepByGlobTransformation(this.glob);

  /// The glob pattern to match.
  final String glob;

  @override
  String get describe => 'keep-by-glob $glob';
}

/// {@template skip_by_glob_transformation}
/// Skips files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class SkipByGlobTransformation extends Transformation {
  /// {@macro skip_by_glob_transformation}
  const SkipByGlobTransformation(this.glob);

  /// The glob pattern to match.
  final String glob;

  @override
  String get describe => 'skip-by-glob $glob';
}

/// {@template relative_transformation}
/// Rewrites file paths to be relative to [basePath].
/// {@endtemplate}
@immutable
final class RelativeTransformation extends Transformation {
  /// {@macro relative_transformation}
  const RelativeTransformation(this.basePath);

  /// The base path to rewrite file paths to be relative to.
  final String basePath;

  @override
  String get describe => 'relative base-path=$basePath';
}
