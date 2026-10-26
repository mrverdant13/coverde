import 'package:meta/meta.dart';

/// {@template coverde.report_page}
/// An extra path that reuses a slot template with extra [variables].
/// {@endtemplate}
@immutable
final class ReportPage {
  /// {@macro coverde.report_page}
  const ReportPage({
    required this.path,
    this.variables = const {},
  });

  /// Liquid path pattern for this page.
  final String path;

  /// Values merged into `variables` for this page only.
  final Map<String, String> variables;
}

/// {@template coverde.report_slot}
/// One Liquid template and the path pattern it writes.
/// {@endtemplate}
@immutable
final class ReportSlot {
  /// {@macro coverde.report_slot}
  const ReportSlot({
    required this.template,
    required this.path,
    this.includeSource = false,
    this.variables = const {},
    this.pages = const [],
  });

  /// Template path relative to the configuration directory.
  final String template;

  /// Liquid path pattern for each rendered node.
  final String path;

  /// Whether this render includes source text on its files.
  final bool includeSource;

  /// Values merged into `variables` for every render of this slot.
  final Map<String, String> variables;

  /// Extra pages that reuse [template] with their own path and variables.
  final List<ReportPage> pages;
}

/// {@template coverde.report_asset}
/// A static file copied into the report destination after templates render.
/// {@endtemplate}
@immutable
final class ReportAsset {
  /// {@macro coverde.report_asset}
  const ReportAsset({
    required this.from,
    required this.to,
    this.render = false,
  });

  /// Source path relative to the configuration directory.
  final String from;

  /// Destination path relative to the report directory.
  final String to;

  /// Whether [from] is a Liquid template rather than a byte copy.
  ///
  /// A rendered asset receives `document`, `variables`, `thresholds`,
  /// `columns`, and `color`.
  final bool render;
}

/// {@template coverde.report_definition}
/// A named report from `coverde.yaml`.
/// {@endtemplate}
sealed class ReportDefinition {
  /// {@macro coverde.report_definition}
  const ReportDefinition({this.collapse = true});

  /// Whether a single-child directory chain becomes one node.
  final bool collapse;
}

/// {@template coverde.console_report_definition}
/// A report that writes one template to a console sink.
/// {@endtemplate}
final class ConsoleReportDefinition extends ReportDefinition {
  /// {@macro coverde.console_report_definition}
  const ConsoleReportDefinition({
    required this.template,
    this.includeSource = false,
    this.destination,
    super.collapse,
  });

  /// Template path relative to the configuration directory.
  final String template;

  /// Whether file lines in this template include source text.
  final bool includeSource;

  /// Absolute file that receives the report, when set.
  ///
  /// Null prints the report.
  final String? destination;
}

/// {@template coverde.files_report_definition}
/// A report that writes templates into [destination].
/// {@endtemplate}
final class FilesReportDefinition extends ReportDefinition {
  /// {@macro coverde.files_report_definition}
  const FilesReportDefinition({
    required this.destination,
    this.root,
    this.directory,
    this.file,
    this.assets = const [],
    super.collapse,
  });

  /// Absolute directory that receives the rendered files.
  final String destination;

  /// Template for the tree root, when set.
  final ReportSlot? root;

  /// Template for directories below the root.
  ///
  /// When [root] is omitted, the root node uses this slot too.
  final ReportSlot? directory;

  /// Template for each source file.
  final ReportSlot? file;

  /// Static files copied after the templates render.
  final List<ReportAsset> assets;
}
