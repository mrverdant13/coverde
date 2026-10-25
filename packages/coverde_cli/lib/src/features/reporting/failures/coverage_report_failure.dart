import 'package:coverde/src/entities/coverde_failure.dart';

/// {@template coverde.coverage_report_failure}
/// A failure raised while defining or rendering a coverage report.
/// {@endtemplate}
sealed class CoverageReportFailure extends CoverdeFailure {
  /// {@macro coverde.coverage_report_failure}
  const CoverageReportFailure();
}

/// {@template coverde.coverage_report_definition_failure}
/// A failure raised when a report definition is missing or invalid.
/// {@endtemplate}
final class CoverageReportDefinitionFailure extends CoverageReportFailure {
  /// {@macro coverde.coverage_report_definition_failure}
  const CoverageReportDefinitionFailure({required this.readableMessage});

  @override
  final String readableMessage;
}

/// {@template coverde.unknown_coverage_report_failure}
/// A failure raised when a requested report name is not defined.
/// {@endtemplate}
final class UnknownCoverageReportFailure extends CoverageReportFailure {
  /// {@macro coverde.unknown_coverage_report_failure}
  const UnknownCoverageReportFailure({
    required this.reportName,
    required this.configPath,
    required this.availableReports,
  });

  /// The report name that was requested.
  final String reportName;

  /// The configuration file that was read.
  final String configPath;

  /// Report names defined in [configPath], sorted.
  final List<String> availableReports;

  @override
  String get readableMessage {
    final available =
        availableReports.isEmpty ? 'none' : availableReports.join(', ');
    return 'Unknown report `$reportName` in `$configPath`.\n'
        'Available reports: $available.';
  }
}
