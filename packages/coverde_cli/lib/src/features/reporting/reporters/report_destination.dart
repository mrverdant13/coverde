import 'package:universal_io/io.dart';

/// {@template coverde.report_destination}
/// Where a coverage reporter writes its output.
/// {@endtemplate}
sealed class ReportDestination {
  /// {@macro coverde.report_destination}
  const ReportDestination();
}

/// {@template coverde.console_report_destination}
/// A console sink that receives the whole report as text.
/// {@endtemplate}
final class ConsoleReportDestination extends ReportDestination {
  /// {@macro coverde.console_report_destination}
  const ConsoleReportDestination(this.sink);

  /// The sink that receives the rendered text.
  final StringSink sink;
}

/// {@template coverde.directory_report_destination}
/// A directory that receives one or more report files.
/// {@endtemplate}
final class DirectoryReportDestination extends ReportDestination {
  /// {@macro coverde.directory_report_destination}
  const DirectoryReportDestination(this.directory);

  /// The directory that contains the rendered files.
  final Directory directory;
}
