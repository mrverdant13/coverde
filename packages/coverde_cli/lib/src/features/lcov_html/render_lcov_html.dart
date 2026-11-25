import 'dart:isolate';

import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_report_request.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/reporters/report_destination.dart';
import 'package:coverde/src/features/reporting/reporters/template_coverage_reporter.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template coverde.render_lcov_html_report}
/// Writes the built-in LCOV HTML report for [document] into [output].
///
/// [medium] and [high] are percentages from 0 to 100, and [medium] is less
/// than [high]. A rate below [medium] is low, a rate below [high] is medium,
/// and any other rate is high.
///
/// [date] is the test date printed in the page header. When it is omitted,
/// the trace modification time is used, or the current time when the trace
/// has none.
/// {@endtemplate}
Future<void> renderLcovHtmlReport({
  required CoverageDocument document,
  required CoverageSourceReader sources,
  required Directory output,
  DateTime? date,
  num medium = 75,
  num high = 90,
}) async {
  _checkLimit('medium', medium);
  _checkLimit('high', high);
  if (medium >= high) {
    throw ArgumentError('medium must be less than high.');
  }
  final templates = await _templateDirectory();
  final reporter = TemplateCoverageReporter(
    definition: _definition(output.path),
    baseDirectory: templates,
  );
  await reporter.render(
    CoverageReportRequest(
      document: document,
      sources: sources,
      destination: DirectoryReportDestination(output),
      variables: {'date': _formatDate(date ?? document.traceModifiedAt)},
      thresholds: {'lcov-lo': medium, 'lcov-hi': high},
    ),
  );
}

Future<String> _templateDirectory() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:coverde/src/features/lcov_html/templates/folder.liquid'),
  );
  if (uri == null) {
    // coverage:ignore-start
    throw const CoverageTemplateRenderFailure(
      readableMessage: 'Built-in LCOV HTML templates were not found.',
    );
    // coverage:ignore-end
  }
  return p.dirname(uri.toFilePath());
}

void _checkLimit(String name, num value) {
  if (value < 0 || value > 100) {
    throw ArgumentError.value(value, name, 'Must be from 0 to 100.');
  }
}

String _formatDate(DateTime? date) {
  final local = (date ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

FilesReportDefinition _definition(String destination) {
  const assets = [
    'gcov.css',
    'amber.png',
    'emerald.png',
    'glass.png',
    'ruby.png',
    'snow.png',
    'updown.png',
  ];
  return FilesReportDefinition(
    destination: destination,
    collapse: false,
    root: ReportSlot(
      template: 'folder.liquid',
      path: 'index.html',
      variables: const {'sort': 'name'},
      pages: _sortPages(''),
    ),
    directory: ReportSlot(
      template: 'folder.liquid',
      path: '{{ directory.path | report_path }}/index.html',
      variables: const {'sort': 'name'},
      pages: _sortPages('{{ directory.path | report_path }}'),
    ),
    file: const ReportSlot(
      template: 'file.liquid',
      path: '{{ file.path | report_path }}.gcov.html',
      includeSource: true,
      variables: {'view': 'source'},
      pages: [
        ReportPage(
          path: '{{ file.path | report_path }}.func.html',
          variables: {'view': 'func'},
        ),
        ReportPage(
          path: '{{ file.path | report_path }}.func-c.html',
          variables: {'view': 'func-c'},
        ),
      ],
    ),
    assets: [for (final name in assets) ReportAsset(from: name, to: name)],
  );
}

List<ReportPage> _sortPages(String directory) {
  String page(String name) => directory.isEmpty ? name : '$directory/$name';
  return [
    ReportPage(
      path: page('index-sort-l.html'),
      variables: const {'sort': 'line'},
    ),
    ReportPage(
      path: page('index-sort-b.html'),
      variables: const {'sort': 'branch'},
    ),
    ReportPage(
      path: page('index-sort-f.html'),
      variables: const {'sort': 'function'},
    ),
  ];
}
