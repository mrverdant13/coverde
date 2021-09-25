import 'package:meta/meta.dart';

/// {@template cov_line}
/// # Covered Line Data
///
/// A representation of coverage data for a line of code.
///
/// The data includes the [lineNumber] in the source file, the [hitsNumber] or
/// number of executions of the line in tests, and the [checksum] value, if any.
/// {@endtemplate}
@immutable
class CovLine {
  /// Create a [CovLine] instance.
  ///
  /// {@macro cov_line}
  @visibleForTesting
  CovLine({
    required this.lineNumber,
    required this.hitsNumber,
    required this.checksum,
  });

  /// Create a [CovLine] from a [data] trace line.
  ///
  /// The [data] string should be the content of a line in a tracefile that
  /// starts with the [tag] prefix.
  ///
  /// {@macro cov_line}
  factory CovLine.parse(String data) {
    // Trim tag if it is present.
    final covLineValuesString =
        data.startsWith(tag) ? data.substring(tag.length) : data;

    // Create and return the resulting coverage line data.
    final valueStrings = covLineValuesString.split(',');
    return CovLine(
      lineNumber: int.parse(valueStrings[0]),
      hitsNumber: int.parse(valueStrings[1]),
      checksum: valueStrings.length == 3 ? int.parse(valueStrings[2]) : null,
    );
  }

  /// The number of line in a source file whose data is represented by this
  /// instance.
  final int lineNumber;

  /// The number of executions of the source line.
  final int hitsNumber;

  /// The optional checksum value that validates this data.
  final int? checksum;

  /// Whether the line of code has been executed in tests.
  late final hasBeenHit = hitsNumber > 0;

  /// {@template cov_line.tag}
  /// The tag or prefix that identifies a line in a tracefile that contains
  /// coverage data for a line of code from a source file.
  /// {@endtemplate}
  static const tag = 'DA:';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CovLine &&
        other.lineNumber == lineNumber &&
        other.hitsNumber == hitsNumber &&
        other.checksum == checksum;
  }

  @override
  int get hashCode =>
      lineNumber.hashCode ^ hitsNumber.hashCode ^ checksum.hashCode;
}
