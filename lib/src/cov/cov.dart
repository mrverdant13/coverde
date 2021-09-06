import 'package:args/command_runner.dart';
import 'package:cov_utils/src/cov/filter/filter.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> cov(List<String> args) async {
  final runner = CommandRunner<void>(
    'cov',
    'A set of commands that encapsulate coverage-related functionalities.',
  ) //
    ..addCommand(FilterCommand());

  await runner.run(args);
}
