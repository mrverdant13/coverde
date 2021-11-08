import 'package:coverde/src/entities/tracefile.dart';

/// {@template min_cov_exception}
/// An exception that indicates that the minimum coverage value has not been
/// reached.
/// {@endtemplate}
class MinCoverageException implements Exception {
  /// {@macro min_cov_exception}
  const MinCoverageException({
    required this.minCoverage,
    required this.tracefile,
  });

  /// The expected minimum coverage value.
  final int minCoverage;

  /// The tracefile with a coverage value lower than the expected [minCoverage].
  final Tracefile tracefile;

  @override
  String toString() => '''
The minimum coverage value has not been reached.
Expected min coverage: $minCoverage %.
Actual coverage: ${tracefile.coverageString} %.
''';
}
