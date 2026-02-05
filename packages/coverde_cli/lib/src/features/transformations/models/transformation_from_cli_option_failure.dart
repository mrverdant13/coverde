part of 'transformation.dart';

/// {@template coverde.transformation_from_cli_option_failure}
/// A failure that occurs when creating a [Transformation] from a CLI option.
/// {@endtemplate}
@immutable
sealed class TransformationFromCliOptionFailure implements Exception {
  /// {@macro coverde.transformation_from_cli_option_failure}
  const TransformationFromCliOptionFailure();
}

/// {@template coverde.transformation_from_cli_option_invalid_arguments_failure}
/// A failure that occurs when the arguments for a transformation are invalid.
/// {@endtemplate}
@immutable
sealed class TransformationFromCliOptionInvalidArgumentsFailure
    extends TransformationFromCliOptionFailure {
  /// {@macro coverde.transformation_from_cli_option_invalid_arguments_failure}
  const TransformationFromCliOptionInvalidArgumentsFailure({
    required this.transformationIdentifier,
  });

  /// The identifier of the transformation.
  final String transformationIdentifier;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.transformation_from_cli_option_invalid_regex_pattern_failure}
/// A failure that occurs when the regex pattern for a transformation is
/// invalid.
/// {@endtemplate}
@immutable
final class TransformationFromCliOptionInvalidRegexPatternFailure
    extends TransformationFromCliOptionInvalidArgumentsFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.transformation_from_cli_option_invalid_regex_pattern_failure}
  const TransformationFromCliOptionInvalidRegexPatternFailure({
    required super.transformationIdentifier,
    required this.regex,
  });

  /// The regex pattern.
  final String regex;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.transformation_from_cli_option_invalid_glob_pattern_failure}
/// A failure that occurs when the glob pattern for a transformation is invalid.
/// {@endtemplate}
@immutable
final class TransformationFromCliOptionInvalidGlobPatternFailure
    extends TransformationFromCliOptionInvalidArgumentsFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.transformation_from_cli_option_invalid_glob_pattern_failure}
  const TransformationFromCliOptionInvalidGlobPatternFailure({
    required super.transformationIdentifier,
    required this.glob,
  });

  /// The glob pattern.
  final String glob;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.transformation_from_cli_option_invalid_numeric_comparison_failure}
/// A failure that occurs when the numeric comparison for a transformation is
/// invalid.
/// {@endtemplate}
@immutable
final class TransformationFromCliOptionInvalidNumericComparisonFailure
    extends TransformationFromCliOptionInvalidArgumentsFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.transformation_from_cli_option_invalid_numeric_comparison_failure}
  const TransformationFromCliOptionInvalidNumericComparisonFailure({
    required super.transformationIdentifier,
    required this.comparison,
  });

  /// The numeric comparison.
  final String comparison;
}

/// {@template coverde.transformation_from_cli_option_unknown_preset_failure}
/// A failure that occurs when a referenced preset is not found in the list of
/// available presets.
/// {@endtemplate}
@immutable
final class TransformationFromCliOptionUnknownPresetFailure
    extends TransformationFromCliOptionFailure {
  /// {@macro coverde.transformation_from_cli_option_unknown_preset_failure}
  const TransformationFromCliOptionUnknownPresetFailure({
    required this.unknownPreset,
    required this.availablePresets,
  });

  /// The unknown preset name.
  final String unknownPreset;

  /// The available preset names.
  final List<String> availablePresets;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.transformation_from_cli_option_unsupported_transformation_failure}
/// A failure that occurs when a transformation is not supported.
/// {@endtemplate}
@immutable
final class TransformationFromCliOptionUnsupportedTransformationFailure
    extends TransformationFromCliOptionFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.transformation_from_cli_option_unsupported_transformation_failure}
  const TransformationFromCliOptionUnsupportedTransformationFailure({
    required this.unsupportedTransformation,
  });

  /// The unsupported transformation.
  final String unsupportedTransformation;
}
