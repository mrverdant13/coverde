import 'package:collection/collection.dart';
import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

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
    String? externalPresetBaseDirectory,
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
      case ExternalPresetTransformation.identifier:
        return ExternalPresetTransformation.fromCliArgument(
          argument,
          baseDirectory: externalPresetBaseDirectory ?? Directory.current.path,
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
    ExternalPresetTransformation.identifier,
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
    this.sourceFile,
  });

  /// The identifier for this transformation.
  static const identifier = 'preset';

  /// The preset name.
  final String presetName;

  /// The authored path of the file this preset was loaded from.
  ///
  /// `null` when the preset comes from the same file as the step that
  /// referenced it.
  final String? sourceFile;

  /// The transformations in this preset (may include nested
  /// [PresetTransformation]s).
  final List<Transformation> steps;

  /// Label used in `--explain` preset chains.
  String get presetChainLabel =>
      sourceFile == null ? presetName : '$presetName in $sourceFile';

  @override
  String get describe => '$identifier name=$presetName';

  static const _stepsEquality = ListEquality<Transformation>();

  @override
  bool operator ==(Object other) {
    if (other is! PresetTransformation) return false;
    return presetName == other.presetName &&
        sourceFile == other.sourceFile &&
        _stepsEquality.equals(steps, other.steps);
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        presetName,
        sourceFile,
        _stepsEquality.hash(steps),
      ]);
}

/// {@template external_preset_transformation}
/// A reference to a preset defined in another `coverde.yaml` file.
///
/// The file is not read until the reference is resolved.
/// {@endtemplate}
@immutable
final class ExternalPresetTransformation extends Transformation {
  /// {@macro external_preset_transformation}
  const ExternalPresetTransformation({
    required this.filePath,
    required this.presetName,
    required this.baseDirectory,
  });

  /// Creates an [ExternalPresetTransformation] from the CLI argument that
  /// follows `external-preset=`.
  ///
  /// [argument] is `<file>::<name>`, split on the last `::`.
  ///
  /// Throws [TransformationFromCliOptionInvalidExternalPresetValueFailure]
  /// when [argument] does not contain both a file path and a preset name.
  factory ExternalPresetTransformation.fromCliArgument(
    String argument, {
    required String baseDirectory,
  }) {
    const separator = '::';
    final separatorIndex = argument.lastIndexOf(separator);
    final hasBothParts = separatorIndex > 0 &&
        separatorIndex < argument.length - separator.length;
    if (!hasBothParts) {
      throw TransformationFromCliOptionInvalidExternalPresetValueFailure(
        transformationIdentifier: identifier,
        value: argument,
      );
    }
    return ExternalPresetTransformation(
      filePath: argument.substring(0, separatorIndex),
      presetName: argument.substring(separatorIndex + separator.length),
      baseDirectory: baseDirectory,
    );
  }

  /// The identifier for this transformation.
  static const identifier = 'external-preset';

  /// The authored path of the `coverde.yaml` file that defines [presetName].
  final String filePath;

  /// The preset name to load from [filePath].
  final String presetName;

  /// Directory used to resolve a relative [filePath].
  final String baseDirectory;

  @override
  String get describe => '$identifier file=$filePath name=$presetName';

  @override
  bool operator ==(Object other) {
    if (other is! ExternalPresetTransformation) return false;
    return filePath == other.filePath &&
        presetName == other.presetName &&
        baseDirectory == other.baseDirectory;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        filePath,
        presetName,
        baseDirectory,
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

Never _throwUnresolvedExternalPreset(ExternalPresetTransformation step) {
  throw StateError(
    'Unresolved external preset `${step.presetName}` from `${step.filePath}`.',
  );
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
        case ExternalPresetTransformation():
          _throwUnresolvedExternalPreset(step);
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
              step.presetChainLabel,
            ],
          );
        case ExternalPresetTransformation():
          _throwUnresolvedExternalPreset(step);
        case LeafTransformation():
          yield (
            transformation: step,
            presets: precedingPresets,
          );
      }
    }
  }
}
