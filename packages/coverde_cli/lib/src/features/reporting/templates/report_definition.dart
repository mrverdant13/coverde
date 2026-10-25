import 'package:meta/meta.dart';

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
  });

  /// Template path relative to the configuration directory.
  final String template;

  /// Liquid path pattern for each rendered node.
  final String path;

  /// Whether a file render includes source text.
  ///
  /// Only file slots use this. Root and directory renders never include it.
  final bool includeSource;
}

/// {@template coverde.report_asset}
/// A static file copied into the report destination after templates render.
/// {@endtemplate}
@immutable
final class ReportAsset {
  /// {@macro coverde.report_asset}
  const ReportAsset({required this.from, required this.to});

  /// Source path relative to the configuration directory.
  final String from;

  /// Destination path relative to the report directory.
  final String to;
}

/// {@template coverde.report_definition}
/// A named report from `coverde.yaml`.
/// {@endtemplate}
sealed class ReportDefinition {
  /// {@macro coverde.report_definition}
  const ReportDefinition();
}

/// {@template coverde.console_report_definition}
/// A report that writes one template to a console sink.
/// {@endtemplate}
final class ConsoleReportDefinition extends ReportDefinition {
  /// {@macro coverde.console_report_definition}
  const ConsoleReportDefinition({required this.template});

  /// Template path relative to the configuration directory.
  final String template;
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
