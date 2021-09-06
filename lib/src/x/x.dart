import 'package:args/command_runner.dart';
import 'package:cov_utils/src/x/rm/rm.dart';

/// A command invocation function that provides generic functionalities.
Future<void> x(List<String> args) async {
  final runner = CommandRunner<void>(
    'x',
    'A set of commands for generic functionalities.',
  ) //
    ..addCommand(RmCommand());

  await runner.run(args);
}
