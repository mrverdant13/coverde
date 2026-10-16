import 'package:coverde/src/entities/coverde_failure.dart';

/// {@template coverde.coverage_trace_format_failure}
/// A failure raised when a trace is not valid LCOV for the coverage document.
/// {@endtemplate}
final class CoverageTraceFormatFailure extends CoverdeFailure {
  /// {@macro coverde.coverage_trace_format_failure}
  const CoverageTraceFormatFailure({required this.readableMessage});

  @override
  final String readableMessage;
}
