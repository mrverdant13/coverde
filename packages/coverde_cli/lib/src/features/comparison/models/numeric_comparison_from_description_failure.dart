part of 'numeric_comparison.dart';

/// {@template coverde.numeric_comparison_from_description_failure}
/// A failure that occurs when creating a [NumericComparison] from a
/// description.
/// {@endtemplate}
@immutable
sealed class NumericComparisonFromDescriptionFailure implements Exception {
  /// {@macro coverde.numeric_comparison_from_description_failure}
  const NumericComparisonFromDescriptionFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.numeric_comparison_from_description_invalid_range_bound_indicator_failure}
/// Thrown when an invalid range bound indicator is encountered while attempting
/// to create a [NumericComparison] from its description.
/// {@endtemplate}
@immutable
final class NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure
    extends NumericComparisonFromDescriptionFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.numeric_comparison_from_description_invalid_range_bound_indicator_failure}
  const NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure({
    required this.indicator,
    required this.allowedIndicators,
  });

  /// The invalid indicator encountered.
  final String indicator;

  /// The list of allowed indicator characters.
  final List<String> allowedIndicators;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.numeric_comparison_from_description_invalid_range_bounds_order_failure}
/// Thrown when the lower bound of a range comparison is greater than or equal
/// to the upper bound.
/// {@endtemplate}
@immutable
final class NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure<
    T extends num> extends NumericComparisonFromDescriptionFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.numeric_comparison_from_description_invalid_range_bounds_order_failure}
  const NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure({
    required this.lowerReference,
    required this.upperReference,
  });

  /// The lower bound of the range comparison.
  final T lowerReference;

  /// The upper bound of the range comparison.
  final T upperReference;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.numeric_comparison_from_description_invalid_raw_reference_failure}
/// Thrown when the reference value from the description cannot be parsed into
/// the expected type.
/// {@endtemplate}
@immutable
final class NumericComparisonFromDescriptionInvalidRawReferenceFailure
    extends NumericComparisonFromDescriptionFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.numeric_comparison_from_description_invalid_raw_reference_failure}
  const NumericComparisonFromDescriptionInvalidRawReferenceFailure({
    required this.rawReference,
    this.exception,
  });

  /// The raw reference string that failed to parse.
  final String rawReference;

  /// The underlying exception that describes why parsing failed.
  final Object? exception;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.numeric_comparison_from_description_invalid_identifier_failure}
/// Thrown when an unrecognized identifier is used in the comparison
/// description.
///
/// The identifier must match one of the set of allowed identifiers for the
/// numeric comparison.
/// {@endtemplate}
@immutable
final class NumericComparisonFromDescriptionInvalidIdentifierFailure
    extends NumericComparisonFromDescriptionFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.numeric_comparison_from_description_invalid_identifier_failure}
  const NumericComparisonFromDescriptionInvalidIdentifierFailure({
    required this.identifier,
    required this.allowedIdentifiers,
  });

  /// The invalid identifier found in the description.
  final String identifier;

  /// The list of allowed identifiers for [NumericComparison].
  final List<String> allowedIdentifiers;
}
