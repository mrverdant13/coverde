import 'package:coverde/coverde.dart';

/// {@template coverde_cli.check_failure}
/// The interface for [CheckCommand] failures.
/// {@endtemplate}
sealed class CoverdeCheckFailure extends CoverdeFailure {
  /// {@macro coverde_cli.check_failure}
  const CoverdeCheckFailure();
}

/// {@template coverde_cli.check_invalid_input_failure}
/// The interface for [CheckCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeCheckInvalidInputFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_invalid_input_failure}
  const CoverdeCheckInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [CheckCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.check_more_than_one_argument_failure}
/// A [CheckCommand] failure that indicates that more than one argument was
/// provided.
/// {@endtemplate}
final class CoverdeCheckMoreThanOneArgumentFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_more_than_one_argument_failure}
  const CoverdeCheckMoreThanOneArgumentFailure({
    required super.usageMessage,
  }) : super(
          invalidInputDescription:
              'Only one argument (minimum coverage threshold) is expected.',
        );
}

/// {@template coverde_cli.check_missing_minimum_coverage_threshold_failure}
/// A [CheckCommand] failure that indicates that the minimum coverage threshold
/// was not provided.
/// {@endtemplate}
final class CoverdeCheckMissingMinimumCoverageThresholdFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_missing_minimum_coverage_threshold_failure}
  const CoverdeCheckMissingMinimumCoverageThresholdFailure({
    required super.usageMessage,
  }) : super(
          invalidInputDescription: 'Missing minimum coverage threshold.',
        );
}

/// {@template coverde_cli.check_invalid_minimum_coverage_threshold_failure}
/// A [CheckCommand] failure that indicates that the minimum coverage threshold
/// was provided but is invalid.
/// {@endtemplate}
final class CoverdeCheckInvalidMinimumCoverageThresholdFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_invalid_minimum_coverage_threshold_failure}
  const CoverdeCheckInvalidMinimumCoverageThresholdFailure({
    required super.usageMessage,
  }) : super(
          invalidInputDescription: 'Invalid minimum coverage threshold.\n'
              'It should be a positive number not greater than 100 '
              '[0.0, 100.0].',
        );
}

/// {@template coverde_cli.check_invalid_trace_file_failure}
/// The interface for [CheckCommand] failures that indicates that an invalid
/// trace file was provided.
/// {@endtemplate}
sealed class CoverdeCheckInvalidTraceFileFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_invalid_trace_file_failure}
  const CoverdeCheckInvalidTraceFileFailure({
    required this.traceFilePath,
  });

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.check_trace_file_not_found_failure}
/// A [CheckCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeCheckTraceFileNotFoundFailure
    extends CoverdeCheckInvalidTraceFileFailure {
  /// {@macro coverde_cli.check_trace_file_not_found_failure}
  const CoverdeCheckTraceFileNotFoundFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.check_empty_trace_file_failure}
/// A [CheckCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeCheckEmptyTraceFileFailure
    extends CoverdeCheckInvalidTraceFileFailure {
  /// {@macro coverde_cli.check_empty_trace_file_failure}
  const CoverdeCheckEmptyTraceFileFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage =>
      'No coverage data found in the trace file located at `$traceFilePath`.';
}

/// {@template coverde_cli.check_coverage_below_minimum_failure}
/// A [CheckCommand] failure that indicates that the coverage value is below the
/// minimum coverage threshold.
/// {@endtemplate}
final class CoverdeCheckCoverageBelowMinimumFailure
    extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_coverage_below_minimum_failure}
  const CoverdeCheckCoverageBelowMinimumFailure({
    required this.minimumCoverage,
    required this.traceFile,
  });

  /// The minimum coverage threshold.
  final double minimumCoverage;

  /// The actual coverage value.
  double get actualCoverage => traceFile.coverage;

  /// The trace file.
  final TraceFile traceFile;

  @override
  String get readableMessage => '''
The minimum coverage value has not been reached.
Expected min coverage: ${minimumCoverage.toStringAsFixed(2)} %.
Actual coverage: ${traceFile.coverageString} %.
''';
}
