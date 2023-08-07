import 'package:coverde/src/entities/coverde.exception.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:io/io.dart';

/// {@template min_cov_exception}
/// An exception that indicates that the minimum coverage value has not been
/// reached.
/// {@endtemplate}
class MinCoverageException extends CoverdeException {
  /// {@macro min_cov_exception}
  const MinCoverageException({
    required this.minCoverage,
    required this.tracefile,
  });

  /// The expected minimum coverage value.
  final double minCoverage;

  /// The tracefile with a coverage value lower than the expected [minCoverage].
  final Tracefile tracefile;

  @override
  ExitCode get code => ExitCode.software;

  @override
  String get message => '''
The minimum coverage value has not been reached.
Expected min coverage: ${minCoverage.toStringAsFixed(2)} %.
Actual coverage: ${tracefile.coverageString} %.
''';
}
