import 'package:args/command_runner.dart';
import 'package:cov_utils/src/commands/cov/filter/filter.dart';
import 'package:cov_utils/src/commands/cov/value/value.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> cov(List<String> args) async {
  final runner = CommandRunner<void>(
    'cov',
    'A set of commands that encapsulate coverage-related functionalities.',
  ) //
    ..addCommand(FilterCommand())
    ..addCommand(ValueCommand());
  await runner.run(args);
}
