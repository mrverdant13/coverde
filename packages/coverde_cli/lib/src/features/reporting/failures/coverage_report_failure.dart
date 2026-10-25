import 'package:coverde/src/entities/coverde_failure.dart';
import 'package:universal_io/io.dart';

/// {@template coverde.coverage_report_failure}
/// A failure raised while defining or rendering a coverage report.
/// {@endtemplate}
sealed class CoverageReportFailure extends CoverdeFailure {
  /// {@macro coverde.coverage_report_failure}
  const CoverageReportFailure();
}

/// {@template coverde.coverage_report_source_read_failure}
/// A failure raised when a source file exists but cannot be read.
/// {@endtemplate}
final class CoverageReportSourceReadFailure extends CoverageReportFailure {
  /// {@macro coverde.coverage_report_source_read_failure}
  CoverageReportSourceReadFailure.fromFileSystemException({
    required this.path,
    required FileSystemException exception,
  }) : errorMessage = [
         exception.message,
         if (exception.osError case final osError?) osError.message,
       ].join('\n');

  /// The source path that could not be read.
  final String path;

  /// The underlying file-system message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to read source file at `$path`.\n$errorMessage';
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

/// {@template coverde.coverage_template_render_failure}
/// A failure raised when a Liquid template cannot be rendered.
/// {@endtemplate}
final class CoverageTemplateRenderFailure extends CoverageReportFailure {
  /// {@macro coverde.coverage_template_render_failure}
  const CoverageTemplateRenderFailure({required this.readableMessage});

  @override
  final String readableMessage;
}

/// {@template coverde.coverage_report_path_failure}
/// A failure raised when a rendered path escapes its root directory.
/// {@endtemplate}
final class CoverageReportPathFailure extends CoverageReportFailure {
  /// {@macro coverde.coverage_report_path_failure}
  const CoverageReportPathFailure({required this.readableMessage});

  @override
  final String readableMessage;
}

/// {@template coverde.coverage_report_destination_failure}
/// A failure raised when a report file cannot be created or written.
/// {@endtemplate}
final class CoverageReportDestinationFailure extends CoverageReportFailure {
  /// {@macro coverde.coverage_report_destination_failure}
  CoverageReportDestinationFailure.fromFileSystemException({
    required this.path,
    required FileSystemException exception,
  }) : errorMessage = [
         exception.message,
         if (exception.osError case final osError?) osError.message,
       ].join('\n');

  /// The path that could not be written.
  final String path;

  /// The underlying file-system message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to write report file at `$path`.\n$errorMessage';
}
