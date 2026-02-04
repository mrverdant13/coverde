import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';

part 'transformation_from_cli_option_failure.dart';

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

  /// Creates a [Transformation] from a CLI option.
  ///
  /// Throws [TransformationFromCliOptionFailure] if an issue occurs.
  factory Transformation.fromCliOption(
    String option, {
    List<PresetTransformation> presets = const [],
  }) {
    final [identifier, ...rest] = option.split('=');
    final argument = rest.join('=');
    switch (identifier) {
      case 'keep-by-regex':
        final RegExp regex;
        try {
          regex = RegExp(argument);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidRegexPatternFailure(
              transformationIdentifier: identifier,
              regex: argument,
            ),
            stackTrace,
          );
        }
        return KeepByRegexTransformation(regex);
      case 'skip-by-regex':
        final RegExp regex;
        try {
          regex = RegExp(argument);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidRegexPatternFailure(
              transformationIdentifier: identifier,
              regex: argument,
            ),
            stackTrace,
          );
        }
        return SkipByRegexTransformation(regex);
      case 'keep-by-glob':
        final Glob glob;
        try {
          glob = Glob(argument);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidGlobPatternFailure(
              transformationIdentifier: identifier,
              glob: argument,
            ),
            stackTrace,
          );
        }
        return KeepByGlobTransformation(glob);
      case 'skip-by-glob':
        final Glob glob;
        try {
          glob = Glob(argument);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidGlobPatternFailure(
              transformationIdentifier: identifier,
              glob: argument,
            ),
            stackTrace,
          );
        }
        return SkipByGlobTransformation(glob);
      case 'relative':
        final basePath = argument;
        return RelativeTransformation(basePath);
      case 'preset':
        final presetName = argument;
        return presets.singleWhere(
          (p) => p.presetName == presetName,
          orElse: () => throw TransformationFromCliOptionUnknownPresetFailure(
            unknownPreset: presetName,
            availablePresets: [for (final preset in presets) preset.presetName],
          ),
        );
      default:
        throw TransformationFromCliOptionUnsupportedTransformationFailure(
          unsupportedTransformation: identifier,
        );
    }
  }

  /// Human-readable description of this transformation.
  String get describe;
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

  /// The identifier for this transformation.
  static const identifier = 'preset';

  /// The preset name.
  final String presetName;

  /// The transformations in this preset (may include nested
  /// [PresetTransformation]s).
  final List<Transformation> steps;

  @override
  String get describe => '$identifier name=$presetName';

  static const _stepsEquality = ListEquality<Transformation>();

  @override
  bool operator ==(Object other) {
    if (other is! PresetTransformation) return false;
    return presetName == other.presetName &&
        _stepsEquality.equals(steps, other.steps);
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        presetName,
        _stepsEquality.hash(steps),
      ]);
}

/// {@template keep_by_regex_transformation}
/// Keeps only files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class KeepByRegexTransformation extends Transformation {
  /// {@macro keep_by_regex_transformation}
  const KeepByRegexTransformation(this.regex);

  /// The identifier for this transformation.
  static const identifier = 'keep-by-regex';

  /// The regex pattern to match.
  final RegExp regex;

  @override
  String get describe => '$identifier pattern=${regex.pattern}';

  @override
  bool operator ==(Object other) {
    if (other is! KeepByRegexTransformation) return false;
    return regex == other.regex;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        regex,
      ]);
}

/// {@template skip_by_regex_transformation}
/// Skips files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class SkipByRegexTransformation extends Transformation {
  /// {@macro skip_by_regex_transformation}
  const SkipByRegexTransformation(this.regex);

  /// The identifier for this transformation.
  static const identifier = 'skip-by-regex';

  /// The regex pattern to match.
  final RegExp regex;

  @override
  String get describe => '$identifier pattern=${regex.pattern}';

  @override
  bool operator ==(Object other) {
    if (other is! SkipByRegexTransformation) return false;
    return regex == other.regex;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        regex,
      ]);
}

/// {@template keep_by_glob_transformation}
/// Keeps only files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class KeepByGlobTransformation extends Transformation {
  /// {@macro keep_by_glob_transformation}
  const KeepByGlobTransformation(this.glob);

  /// The identifier for this transformation.
  static const identifier = 'keep-by-glob';

  /// The glob pattern to match.
  final Glob glob;

  @override
  String get describe => '$identifier pattern=${glob.pattern}';

  @override
  bool operator ==(Object other) {
    if (other is! KeepByGlobTransformation) return false;
    return glob.pattern == other.glob.pattern;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        glob.pattern,
      ]);
}

/// {@template skip_by_glob_transformation}
/// Skips files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class SkipByGlobTransformation extends Transformation {
  /// {@macro skip_by_glob_transformation}
  const SkipByGlobTransformation(this.glob);

  /// The identifier for this transformation.
  static const identifier = 'skip-by-glob';

  /// The glob pattern to match.
  final Glob glob;

  @override
  String get describe => '$identifier pattern=${glob.pattern}';

  @override
  bool operator ==(Object other) {
    if (other is! SkipByGlobTransformation) return false;
    return glob.pattern == other.glob.pattern;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        glob.pattern,
      ]);
}

/// {@template relative_transformation}
/// Rewrites file paths to be relative to [basePath].
/// {@endtemplate}
@immutable
final class RelativeTransformation extends Transformation {
  /// {@macro relative_transformation}
  const RelativeTransformation(this.basePath);

  /// The identifier for this transformation.
  static const identifier = 'relative';

  /// The base path to rewrite file paths to be relative to.
  final String basePath;

  @override
  String get describe => '$identifier base-path=$basePath';

  @override
  bool operator ==(Object other) {
    if (other is! RelativeTransformation) return false;
    return basePath == other.basePath;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        basePath,
      ]);
}

/// A collection of transformations.
typedef Transformations = Iterable<Transformation>;

/// A tuple of a transformation and its preset chains.
typedef TransformationWithPresetChains = ({
  Transformation transformation,
  List<String> presets,
});

/// Extension methods for [Iterable<Transformation>].
extension ExtendedTransformations on Iterable<Transformation> {
  /// Flattens this transformation to leaf steps only.
  ///
  /// [PresetTransformation] is expanded; leaf transformations return
  /// themselves.
  Iterable<Transformation> get flattenedSteps sync* {
    for (final step in this) {
      switch (step) {
        case PresetTransformation(:final steps):
          yield* steps.flattenedSteps;
        default:
          yield step;
      }
    }
  }

  /// Returns a list of transformations with their preset chains.
  Iterable<TransformationWithPresetChains> getStepsWithPresetChains({
    List<String> precedingPresets = const [],
  }) sync* {
    for (final step in this) {
      switch (step) {
        case PresetTransformation(:final steps):
          yield* steps.getStepsWithPresetChains(
            precedingPresets: [
              ...precedingPresets,
              step.presetName,
            ],
          );
        default:
          yield (
            transformation: step,
            presets: precedingPresets,
          );
      }
    }
  }
}
