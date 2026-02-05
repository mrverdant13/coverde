import 'package:meta/meta.dart';

part 'numeric_comparison_from_description_failure.dart';

/// Signature for functions that parse a string into a numeric [T] type.
typedef NumericReferenceParser<T extends num> = T Function(String raw);

/// {@template coverde.numeric_comparison}
/// A numeric comparison.
/// {@endtemplate}
sealed class NumericComparison<T extends num> {
  /// {@macro coverde.numeric_comparison}
  const NumericComparison();

  /// Creates a [NumericComparison] from a string [description].
  ///
  /// The [description] is expected to start with an identifier, followed by a
  /// pipe (`|`), and then a reference or range value.
  ///
  /// For example: `eq|10`, `in|[0,10)`.
  ///
  /// The [referenceParser] function parses raw string references to type [T].
  ///
  /// Throws a [NumericComparisonFromDescriptionFailure] if the description is
  /// invalid.
  factory NumericComparison.fromDescription(
    String description,
    NumericReferenceParser<T> referenceParser,
  ) {
    final [identifier, ...rest] = description.split('|');
    final argument = rest.join('|');

    T parseReference(String raw) {
      try {
        return referenceParser(raw);
      } on Object catch (e, stackTrace) {
        Error.throwWithStackTrace(
          NumericComparisonFromDescriptionInvalidRawReferenceFailure(
            rawReference: raw,
            exception: e,
          ),
          stackTrace,
        );
      }
    }

    switch (identifier) {
      case EqualsNumericComparison.identifier:
        final reference = parseReference(argument);
        return EqualsNumericComparison<T>(reference: reference);
      case NotEqualToNumericComparison.identifier:
        final reference = parseReference(argument);
        return NotEqualToNumericComparison<T>(reference: reference);
      case GreaterThanNumericComparison.identifier:
        final reference = parseReference(argument);
        return GreaterThanNumericComparison(reference: reference);
      case GreaterThanOrEqualToNumericComparison.identifier:
        final reference = parseReference(argument);
        return GreaterThanOrEqualToNumericComparison(reference: reference);
      case LessThanNumericComparison.identifier:
        final reference = parseReference(argument);
        return LessThanNumericComparison(reference: reference);
      case LessThanOrEqualToNumericComparison.identifier:
        final reference = parseReference(argument);
        return LessThanOrEqualToNumericComparison(reference: reference);
      case RangeNumericComparison.identifier:
        final [lowerBoundData, upperBoundData] = argument.split(',');
        final lowerBoundIndicator = lowerBoundData.substring(
          0,
          1,
        );
        final rawLowerBoundReference = lowerBoundData.substring(
          1,
        );
        final upperBoundIndicator = upperBoundData.substring(
          upperBoundData.length - 1,
        );
        final rawUpperBoundReference = upperBoundData.substring(
          0,
          upperBoundData.length - 1,
        );
        final lowerInclusive = switch (lowerBoundIndicator) {
          '[' => true,
          '(' => false,
          _ =>
            // Long class name
            // ignore: lines_longer_than_80_chars
            throw NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure(
              indicator: lowerBoundIndicator,
              allowedIndicators: const ['[', '('],
            ),
        };
        final upperInclusive = switch (upperBoundIndicator) {
          ']' => true,
          ')' => false,
          _ =>
            // Long class name
            // ignore: lines_longer_than_80_chars
            throw NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure(
              indicator: upperBoundIndicator,
              allowedIndicators: const [']', ')'],
            ),
        };
        final lowerReference = parseReference(rawLowerBoundReference);
        final upperReference = parseReference(rawUpperBoundReference);
        return RangeNumericComparison(
          lowerReference: lowerReference,
          upperReference: upperReference,
          lowerInclusive: lowerInclusive,
          upperInclusive: upperInclusive,
        );
      case _:
        throw NumericComparisonFromDescriptionInvalidIdentifierFailure(
          identifier: identifier,
          allowedIdentifiers: identifiers,
        );
    }
  }

  /// The set of valid numeric comparison identifiers.
  static const List<String> identifiers = [
    EqualsNumericComparison.identifier,
    NotEqualToNumericComparison.identifier,
    GreaterThanNumericComparison.identifier,
    GreaterThanOrEqualToNumericComparison.identifier,
    LessThanNumericComparison.identifier,
    LessThanOrEqualToNumericComparison.identifier,
    RangeNumericComparison.identifier,
  ];

  /// Returns true if the [value] matches this comparison.
  bool matches(T value);

  /// Provides a string description of this comparison.
  String get describe;
}

/// {@template coverde.equals_numeric_comparison}
/// Numeric comparison for equality (`==`).
/// {@endtemplate}
@immutable
final class EqualsNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.equals_numeric_comparison}
  const EqualsNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'eq';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value == reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! EqualsNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.not_equal_to_numeric_comparison}
/// Numeric comparison for inequality (`!=`).
/// {@endtemplate}
@immutable
final class NotEqualToNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.not_equal_to_numeric_comparison}
  const NotEqualToNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'neq';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value != reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! NotEqualToNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.greater_than_numeric_comparison}
/// Numeric comparison for greater than (`>`).
/// {@endtemplate}
@immutable
final class GreaterThanNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.greater_than_numeric_comparison}
  const GreaterThanNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'gt';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value > reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! GreaterThanNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.greater_than_or_equal_to_numeric_comparison}
/// Numeric comparison for greater than or equal to (`>=`).
/// {@endtemplate}
@immutable
final class GreaterThanOrEqualToNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.greater_than_or_equal_to_numeric_comparison}
  const GreaterThanOrEqualToNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'gte';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value >= reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! GreaterThanOrEqualToNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.less_than_numeric_comparison}
/// Numeric comparison for less than (`<`).
/// {@endtemplate}
@immutable
final class LessThanNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.less_than_numeric_comparison}
  const LessThanNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'lt';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value < reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! LessThanNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.less_than_or_equal_to_numeric_comparison}
/// Numeric comparison for less than or equal to (`<=`).
/// {@endtemplate}
@immutable
final class LessThanOrEqualToNumericComparison<T extends num>
    extends NumericComparison<T> {
  /// {@macro coverde.less_than_or_equal_to_numeric_comparison}
  const LessThanOrEqualToNumericComparison({
    required this.reference,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'lte';

  /// The reference value to compare against.
  final T reference;

  @override
  bool matches(T value) => value <= reference;

  @override
  String get describe => '$identifier|$reference';

  @override
  bool operator ==(Object other) {
    if (other is! LessThanOrEqualToNumericComparison<T>) return false;
    return reference == other.reference;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        reference,
      ]);
}

/// {@template coverde.range_numeric_comparison}
/// Numeric comparison against a range (`[a,b)`, `(a,b]`, etc.).
///
/// Whether the lower and upper bounds are inclusive or exclusive is determined
/// by [lowerInclusive] and [upperInclusive]. Can match values strictly between,
/// with inclusive endpoints, or both.
/// {@endtemplate}
@immutable
final class RangeNumericComparison<T extends num> extends NumericComparison<T> {
  /// {@macro coverde.range_numeric_comparison}
  const RangeNumericComparison({
    required this.lowerReference,
    required this.upperReference,
    required this.lowerInclusive,
    required this.upperInclusive,
  });

  /// The string identifier for this comparison type.
  static const identifier = 'in';

  /// The lower endpoint of the comparison range.
  final T lowerReference;

  /// The upper endpoint of the comparison range.
  final T upperReference;

  /// If true, `lowerReference` is included in the range (i.e., `>=`).
  final bool lowerInclusive;

  /// If true, `upperReference` is included in the range (i.e., `<=`).
  final bool upperInclusive;

  /// The bracket/parenthesis that indicates whether the lower bound is inclusive.
  String get lowerBoundIndicator => lowerInclusive ? '[' : '(';

  /// The bracket/parenthesis that indicates whether the upper bound is inclusive.
  String get upperBoundIndicator => upperInclusive ? ']' : ')';

  @override
  bool matches(T value) =>
      (value > lowerReference && value < upperReference) ||
      (lowerInclusive && value == lowerReference) ||
      (upperInclusive && value == upperReference);

  @override
  String get describe => '$identifier|'
      '$lowerBoundIndicator'
      '$lowerReference,$upperReference'
      '$upperBoundIndicator';

  @override
  bool operator ==(Object other) {
    if (other is! RangeNumericComparison<T>) return false;
    return lowerReference == other.lowerReference &&
        upperReference == other.upperReference &&
        lowerInclusive == other.lowerInclusive &&
        upperInclusive == other.upperInclusive;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        lowerReference,
        upperReference,
        lowerInclusive,
        upperInclusive,
      ]);
}
