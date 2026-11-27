import 'dart:isolate';

import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_report_request.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/reporters/report_destination.dart';
import 'package:coverde/src/features/reporting/reporters/template_coverage_reporter.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

/// How much of each file `coverde report console` prints.
enum ConsoleReportLevel {
  /// Covered and uncovered files, with the surrounding source of each gap.
  lineContent('line-content'),

  /// Covered and uncovered files, with uncovered line numbers.
  lineNumbers('line-numbers'),

  /// One line per file, then the global rate.
  overview('overview'),

  /// The global rate only.
  none('none');

  const ConsoleReportLevel(this.identifier);

  /// The `--file-coverage-log-level` value.
  final String identifier;
}

/// {@template coverde.render_console_report}
/// The text `coverde value` prints for [document] at [level].
///
/// [ConsoleReportLevel.lineContent] reads source through [sources]. A missing
/// source is left blank here; the command rejects it before rendering.
/// {@endtemplate}
Future<String> renderConsoleReport({
  required CoverageDocument document,
  required CoverageSourceReader sources,
  required ConsoleReportLevel level,
}) async {
  final templates = await _templateDirectory();
  final buffer = StringBuffer();
  await TemplateCoverageReporter(
    definition: ConsoleReportDefinition(
      template: 'console.liquid',
      includeSource: level == ConsoleReportLevel.lineContent,
    ),
    baseDirectory: templates,
  ).render(
    CoverageReportRequest(
      document: document,
      sources: sources,
      destination: ConsoleReportDestination(buffer),
      variables: {'level': level.identifier},
      color: ansiOutputEnabled,
    ),
  );
  return buffer.toString();
}

Future<String> _templateDirectory() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:coverde/src/features/console/templates/console.liquid'),
  );
  if (uri == null) {
    // coverage:ignore-start
    throw const CoverageTemplateRenderFailure(
      readableMessage: 'Built-in console templates were not found.',
    );
    // coverage:ignore-end
  }
  return p.dirname(uri.toFilePath());
}
