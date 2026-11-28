import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// Overrides the terminal width. Tests set this because a test process has
/// no terminal.
@visibleForTesting
int? debugReportColumns;

/// Overrides color for tests. A test process has no terminal.
@visibleForTesting
bool? debugReportColor;

/// Whether a printed report should emit ANSI color.
///
/// A report written to a file stays plain. [printing] is false in that case.
bool reportColor({required bool printing}) {
  if (!printing) return false;
  final override = debugReportColor;
  if (override != null) return override;
  // A test process has no terminal, so ANSI support is not read in tests.
  // coverage:ignore-start
  if (stdout.hasTerminal && stdout.supportsAnsiEscapes) return true;
  // coverage:ignore-end
  return false;
}

/// Whether [definition] prints to the terminal instead of writing a file.
bool reportPrintsToTerminal(ReportDefinition definition) {
  return switch (definition) {
    ConsoleReportDefinition(:final destination) => destination == null,
    FilesReportDefinition() => false,
  };
}

/// The terminal width, or 80 when stdout is not a terminal.
int reportColumns() {
  final override = debugReportColumns;
  if (override != null) return override;
  // A test process has no terminal, so this width is not read in tests.
  // coverage:ignore-start
  if (stdout.hasTerminal) return stdout.terminalColumns;
  // coverage:ignore-end
  return 80;
}
