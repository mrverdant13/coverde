import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde(List<String> args) async {
  final runner = CommandRunner<void>(
    'coverde',
    'A set of commands that encapsulate coverage-related functionalities.',
  ) //
    ..addCommand(FilterCommand())
    ..addCommand(ReportCommand())
    ..addCommand(RmCommand())
    ..addCommand(ValueCommand());
  await runner.run(args);
}
