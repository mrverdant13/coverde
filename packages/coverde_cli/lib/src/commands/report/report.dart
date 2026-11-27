import 'package:coverde/src/commands/commands.dart';

export 'console.dart';
export 'failures.dart';
export 'lcov_html.dart';

/// {@template report_cmd}
/// A command that generates a coverage report.
///
/// A report name is required. `coverde report` with no report prints usage.
/// {@endtemplate}
class ReportCommand extends CoverdeCommand {
  /// {@macro report_cmd}
  ReportCommand() {
    addSubcommand(ConsoleCommand());
    addSubcommand(LcovHtmlCommand());
  }

  @override
  String get description => '''
Generate a coverage report from one or more trace files.

Choose a report. `coverde report` with no report prints usage.''';

  @override
  String get name => 'report';

  @override
  List<String> get aliases => [name[0]];

  @override
  bool get takesArguments => false;
}
