import 'dart:io';

/// # Computable Coverage Entity
///
/// The definition of base values that an instance should implement when it
/// includes coverage data regarding tested lines and total testable lines.
abstract class CovComputable {
  /// The number of tested lines in this instance.
  int get linesHit;

  /// The number of found lines in this instance.
  int get linesFound;

  /// The percentage of code coverage for this instance.
  ///
  /// From **0.00** to **100.00**.
  double get coverage => (linesHit * 100) / linesFound;

  /// The string representation of the [coverage] value.
  ///
  /// From **0.00** to **100.00**.
  String get coverageString => coverage.toStringAsFixed(2);
}

/// # Coverage Filesystem Element
///
/// The definition of the minimum conditions that should be met by a covered
/// filesystem instance.
abstract class CovElement extends CovComputable {
  /// The tested filesystem element.
  FileSystemEntity get source;
}
