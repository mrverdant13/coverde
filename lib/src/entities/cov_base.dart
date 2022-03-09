import 'package:io/ansi.dart';
import 'package:universal_io/io.dart';

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
  double get coverage => ((linesHit * 10000) / linesFound).round() / 100;

  /// The string representation of the [coverage] value.
  ///
  /// From **0.00** to **100.00**.
  String get coverageString => coverage.toStringAsFixed(2);

  /// The string representation of the [coverage] value, hte [linesHit] and the
  /// [linesFound].
  String get coverageDataString => '$coverageString% - $linesHit/$linesFound';
}

/// # Coverage Filesystem Element
///
/// The definition of the minimum conditions that should be met by a covered
/// filesystem instance.
abstract class CovElement extends CovComputable {
  /// The tested filesystem element.
  FileSystemEntity get source;

  /// The string representation of the [coverage] value, hte [linesHit] and the
  /// [linesFound].
  @override
  String get coverageDataString {
    final color = coverage < 100 ? lightRed : lightGreen;
    return '${source.path} ${color.wrap('(${super.coverageDataString})')}';
  }
}
