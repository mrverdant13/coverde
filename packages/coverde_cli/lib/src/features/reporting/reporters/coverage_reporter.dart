import 'package:coverde/src/features/reporting/reporters/coverage_report_request.dart';

/// {@template coverde.coverage_reporter}
/// Renders a [CoverageReportRequest] to its destination.
/// {@endtemplate}
abstract interface class CoverageReporter {
  /// Writes [request] to [CoverageReportRequest.destination].
  Future<void> render(CoverageReportRequest request);
}
