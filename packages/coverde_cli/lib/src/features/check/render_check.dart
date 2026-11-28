import 'dart:isolate';

import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_report_request.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/reporters/report_destination.dart';
import 'package:coverde/src/features/reporting/reporters/template_coverage_reporter.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template coverde.render_check_report}
/// The text `coverde check` prints before it accepts or rejects [document].
///
/// A file appears only when it has an uncovered line. Readable source is
/// shown around those lines. A missing or unresolvable source becomes the
/// uncovered line numbers, and does not fail the render.
/// {@endtemplate}
Future<String> renderCheckReport({required CoverageDocument document}) async {
  final templates = await _templateDirectory();
  final buffer = StringBuffer();
  await TemplateCoverageReporter(
    definition: const ConsoleReportDefinition(
      template: 'check.liquid',
      includeSource: true,
    ),
    baseDirectory: templates,
  ).render(
    CoverageReportRequest(
      document: document,
      sources: const CheckCoverageSourceReader(),
      destination: ConsoleReportDestination(buffer),
      color: ansiOutputEnabled,
    ),
  );
  return buffer.toString();
}

/// Reads source for [renderCheckReport] and treats a missing file as absent.
class CheckCoverageSourceReader implements CoverageSourceReader {
  /// Creates a reader that never throws for a source it cannot open.
  const CheckCoverageSourceReader();

  @override
  List<String>? readLines(String sourcePath) {
    if (!hostCanResolveCoveragePath(
      sourcePath,
      windowsHost: Platform.isWindows,
    )) {
      return null;
    }
    try {
      return const FileCoverageSourceReader().readLines(
        File(sourcePath).absolute.path,
      );
    } on CoverageReportSourceReadFailure {
      return null;
    }
  }
}

Future<String> _templateDirectory() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:coverde/src/features/check/templates/check.liquid'),
  );
  if (uri == null) {
    // coverage:ignore-start
    throw const CoverageTemplateRenderFailure(
      readableMessage: 'Built-in check templates were not found.',
    );
    // coverage:ignore-end
  }
  return p.dirname(uri.toFilePath());
}
