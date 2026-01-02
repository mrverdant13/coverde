import 'package:coverde/coverde.dart';

/// {@template coverde_cli.report_failure}
/// The interface for [ReportCommand] failures.
/// {@endtemplate}
sealed class CoverdeReportFailure extends CoverdeFailure {
  /// {@macro coverde_cli.report_failure}
  const CoverdeReportFailure();
}

/// {@template coverde_cli.report_invalid_input_failure}
/// The interface for [ReportCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeReportInvalidInputFailure extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_invalid_input_failure}
  const CoverdeReportInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [ReportCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.report_invalid_medium_threshold_failure}
/// A [ReportCommand] failure that indicates that an invalid medium threshold
/// was provided.
/// {@endtemplate}
final class CoverdeReportInvalidMediumThresholdFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_medium_threshold_failure}
  const CoverdeReportInvalidMediumThresholdFailure({
    required super.usageMessage,
    required this.rawValue,
  }) : super(
          invalidInputDescription: 'Invalid medium threshold: `$rawValue`.\n'
              'It should be a positive number not greater than 100 '
              '[0.0, 100.0].',
        );

  /// The invalid medium value, if any.
  final String? rawValue;
}

/// {@template coverde_cli.report_invalid_high_threshold_failure}
/// A [ReportCommand] failure that indicates that an invalid high threshold
/// was provided.
/// {@endtemplate}
final class CoverdeReportInvalidHighThresholdFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_high_threshold_failure}
  const CoverdeReportInvalidHighThresholdFailure({
    required super.usageMessage,
    required this.rawValue,
  }) : super(
          invalidInputDescription: 'Invalid high threshold: `$rawValue`.\n'
              'It should be a positive number not greater than 100 '
              '[0.0, 100.0].',
        );

  /// The invalid high value, if any.
  final String? rawValue;
}

/// {@template coverde_cli.report_invalid_threshold_relationship_failure}
/// A [ReportCommand] failure that indicates that the threshold relationship
/// is invalid (medium >= high).
/// {@endtemplate}
final class CoverdeReportInvalidThresholdRelationshipFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_threshold_relationship_failure}
  const CoverdeReportInvalidThresholdRelationshipFailure({
    required super.usageMessage,
    required this.mediumValue,
    required this.highValue,
  }) : super(
          invalidInputDescription:
              'Medium threshold ($mediumValue) must be less than '
              'high threshold ($highValue).',
        );

  /// The medium threshold value.
  final double mediumValue;

  /// The high threshold value.
  final double highValue;
}

/// {@template coverde_cli.report_invalid_trace_file_failure}
/// The interface for [ReportCommand] failures that indicates that an invalid
/// trace file was provided.
/// {@endtemplate}
sealed class CoverdeReportInvalidTraceFileFailure extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_invalid_trace_file_failure}
  const CoverdeReportInvalidTraceFileFailure({
    required this.traceFilePath,
  });

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.report_trace_file_not_found_failure}
/// A [ReportCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeReportTraceFileNotFoundFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_trace_file_not_found_failure}
  const CoverdeReportTraceFileNotFoundFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.report_empty_trace_file_failure}
/// A [ReportCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeReportEmptyTraceFileFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_empty_trace_file_failure}
  const CoverdeReportEmptyTraceFileFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage =>
      'No coverage data found in the trace file at `$traceFilePath`.';
}
