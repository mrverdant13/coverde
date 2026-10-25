import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/reporters/report_destination.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_report_request}
/// The inputs needed to render one coverage report.
/// {@endtemplate}
@immutable
final class CoverageReportRequest {
  /// {@macro coverde.coverage_report_request}
  CoverageReportRequest({
    required this.document,
    required this.sources,
    required this.destination,
    Map<String, String> variables = const {},
  }) : variables = Map<String, String>.unmodifiable(variables);

  /// The coverage to render.
  final CoverageDocument document;

  /// Reads source text when a reporter asks for it.
  final CoverageSourceReader sources;

  /// Where the rendered report is written.
  final ReportDestination destination;

  /// Caller-supplied values.
  ///
  /// The reporter does not interpret the keys. Values are strings.
  final Map<String, String> variables;
}
