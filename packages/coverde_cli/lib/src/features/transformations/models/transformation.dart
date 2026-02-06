import 'package:collection/collection.dart';
import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

part 'transformation_from_cli_option_failure.dart';

/// Separator used when showing nested preset hierarchy (e.g. "preset-a →
/// preset-b").
const String presetChainSeparator = ' → ';

/// Validates that all references in [comparison] are valid coverage percentages
/// (between 0 and 100 inclusive).
///
/// Returns a list of invalid references, or an empty list if all are valid.
List<double> validateCoverageReferences(NumericComparison<double> comparison) {
  final references = switch (comparison) {
    EqualsNumericComparison(:final reference) => [reference],
    NotEqualToNumericComparison(:final reference) => [reference],
    GreaterThanNumericComparison(:final reference) => [reference],
    GreaterThanOrEqualToNumericComparison(:final reference) => [reference],
    LessThanNumericComparison(:final reference) => [reference],
    LessThanOrEqualToNumericComparison(:final reference) => [reference],
    RangeNumericComparison(:final lowerReference, :final upperReference) => [
        lowerReference,
        upperReference,
      ],
  };
  return references.where((ref) => ref < 0 || ref > 100).toList();
}

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
      case KeepByRegexTransformation.identifier:
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
      case SkipByRegexTransformation.identifier:
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
      case KeepByGlobTransformation.identifier:
        final Glob glob;
        try {
          glob = Glob(argument, context: p.posix);
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
      case SkipByGlobTransformation.identifier:
        final Glob glob;
        try {
          glob = Glob(argument, context: p.posix);
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
      case KeepByCoverageTransformation.identifier:
        final NumericComparison<double> comparison;
        try {
          comparison = NumericComparison.fromDescription(
            argument,
            double.parse,
          );
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidNumericComparisonFailure(
              transformationIdentifier: identifier,
              comparison: argument,
            ),
            stackTrace,
          );
        }
        final invalidReferences = validateCoverageReferences(comparison);
        if (invalidReferences.isNotEmpty) {
          throw TransformationFromCliOptionInvalidCoveragePercentageFailure(
            transformationIdentifier: identifier,
            invalidReferences: invalidReferences,
          );
        }
        return KeepByCoverageTransformation(comparison: comparison);
      case SkipByCoverageTransformation.identifier:
        final NumericComparison<double> comparison;
        try {
          comparison = NumericComparison.fromDescription(
            argument,
            double.parse,
          );
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            TransformationFromCliOptionInvalidNumericComparisonFailure(
              transformationIdentifier: identifier,
              comparison: argument,
            ),
            stackTrace,
          );
        }
        final invalidReferences = validateCoverageReferences(comparison);
        if (invalidReferences.isNotEmpty) {
          throw TransformationFromCliOptionInvalidCoveragePercentageFailure(
            transformationIdentifier: identifier,
            invalidReferences: invalidReferences,
          );
        }
        return SkipByCoverageTransformation(comparison: comparison);
      case RelativeTransformation.identifier:
        final basePath = argument;
        return RelativeTransformation(basePath);
      case PresetTransformation.identifier:
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

  /// The available transformation identifiers.
  static const List<String> identifiers = [
    PresetTransformation.identifier,
    KeepByRegexTransformation.identifier,
    SkipByRegexTransformation.identifier,
    KeepByGlobTransformation.identifier,
    SkipByGlobTransformation.identifier,
    KeepByCoverageTransformation.identifier,
    SkipByCoverageTransformation.identifier,
    RelativeTransformation.identifier,
  ];

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

/// {@template leaf_transformation}
/// A leaf transformation, i.e. a transformation that does not contain any other
/// transformations.
/// {@endtemplate}
@immutable
sealed class LeafTransformation extends Transformation {
  /// {@macro leaf_transformation}
  const LeafTransformation();
}

/// {@template keep_by_regex_transformation}
/// Keeps only files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class KeepByRegexTransformation extends LeafTransformation {
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
    return regex.pattern == other.regex.pattern &&
        regex.isCaseSensitive == other.regex.isCaseSensitive &&
        regex.isDotAll == other.regex.isDotAll &&
        regex.isMultiLine == other.regex.isMultiLine &&
        regex.isUnicode == other.regex.isUnicode;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        regex.pattern,
        regex.isCaseSensitive,
        regex.isDotAll,
        regex.isMultiLine,
        regex.isUnicode,
      ]);
}

/// {@template skip_by_regex_transformation}
/// Skips files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class SkipByRegexTransformation extends LeafTransformation {
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
    return regex.pattern == other.regex.pattern &&
        regex.isCaseSensitive == other.regex.isCaseSensitive &&
        regex.isDotAll == other.regex.isDotAll &&
        regex.isMultiLine == other.regex.isMultiLine &&
        regex.isUnicode == other.regex.isUnicode;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        regex.pattern,
        regex.isCaseSensitive,
        regex.isDotAll,
        regex.isMultiLine,
        regex.isUnicode,
      ]);
}

/// {@template keep_by_glob_transformation}
/// Keeps only files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class KeepByGlobTransformation extends LeafTransformation {
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
    return glob.pattern == other.glob.pattern &&
        glob.context == other.glob.context &&
        glob.caseSensitive == other.glob.caseSensitive &&
        glob.recursive == other.glob.recursive;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        glob.pattern,
        glob.context,
        glob.caseSensitive,
        glob.recursive,
      ]);
}

/// {@template skip_by_glob_transformation}
/// Skips files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class SkipByGlobTransformation extends LeafTransformation {
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
    return glob.pattern == other.glob.pattern &&
        glob.context == other.glob.context &&
        glob.caseSensitive == other.glob.caseSensitive &&
        glob.recursive == other.glob.recursive;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        glob.pattern,
        glob.context,
        glob.caseSensitive,
        glob.recursive,
      ]);
}

/// {@template keep_by_coverage_transformation}
/// Keeps only files whose coverage matches the [comparison].
/// {@endtemplate}
@immutable
final class KeepByCoverageTransformation extends LeafTransformation {
  /// {@macro keep_by_coverage_transformation}
  const KeepByCoverageTransformation({
    required this.comparison,
  });

  /// The identifier for this transformation.
  static const identifier = 'keep-by-coverage';

  /// The coverage comparison to apply.
  final NumericComparison<double> comparison;

  @override
  String get describe => '$identifier comparison=${comparison.describe}';

  @override
  bool operator ==(Object other) {
    if (other is! KeepByCoverageTransformation) return false;
    return comparison == other.comparison;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        comparison,
      ]);
}

/// {@template skip_by_coverage_transformation}
/// Skips files whose coverage matches the [comparison].
/// {@endtemplate}
@immutable
final class SkipByCoverageTransformation extends LeafTransformation {
  /// {@macro skip_by_coverage_transformation}
  const SkipByCoverageTransformation({
    required this.comparison,
  });

  /// The identifier for this transformation.
  static const identifier = 'skip-by-coverage';

  /// The coverage comparison to apply.
  final NumericComparison<double> comparison;

  @override
  String get describe => '$identifier comparison=${comparison.describe}';

  @override
  bool operator ==(Object other) {
    if (other is! SkipByCoverageTransformation) return false;
    return comparison == other.comparison;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        comparison,
      ]);
}

/// {@template relative_transformation}
/// Rewrites file paths to be relative to [basePath].
/// {@endtemplate}
@immutable
final class RelativeTransformation extends LeafTransformation {
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
typedef LeafTransformationWithPresetChains = ({
  LeafTransformation transformation,
  List<String> presets,
});

/// Extension methods for [Iterable<Transformation>].
extension ExtendedTransformations on Iterable<Transformation> {
  /// Flattens this transformation to leaf steps only.
  ///
  /// [PresetTransformation] is expanded; leaf transformations return
  /// themselves.
  Iterable<LeafTransformation> get flattenedSteps sync* {
    for (final step in this) {
      switch (step) {
        case PresetTransformation(:final steps):
          yield* steps.flattenedSteps;
        case LeafTransformation():
          yield step;
      }
    }
  }

  /// Returns a list of transformations with their preset chains.
  Iterable<LeafTransformationWithPresetChains> getStepsWithPresetChains({
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
        case LeafTransformation():
          yield (
            transformation: step,
            presets: precedingPresets,
          );
      }
    }
  }
}
