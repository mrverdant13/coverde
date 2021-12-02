import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/utils/cli.data.dart';
import 'package:io/ansi.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:universal_io/io.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde(List<String> args) async {
  final runner = CommandRunner<void>(
    cliName,
    'A set of commands that encapsulate coverage-related functionalities.',
  ) //
    ..addCommand(CheckCommand())
    ..addCommand(FilterCommand())
    ..addCommand(ReportCommand())
    ..addCommand(RmCommand())
    ..addCommand(ValueCommand());
  await runner.run(args);
  await _checkUpdates();
}

Future<void> _checkUpdates() async {
  try {
    final updater = PubUpdater();
    final latestVersion = await updater.getLatestVersion(cliName);
    final isUpToDate = latestVersion == cliVersion;
    if (!isUpToDate) {
      const updateMessage = 'A new version of `$cliName` is available!';
      final styledUpdateMessage = lightYellow.wrap(updateMessage);
      final styledVersionsMessage = '''
${lightGray.wrap(cliVersion)} \u2192 ${lightGreen.wrap(latestVersion)}''';
      final styledCommand = wrapWith(
        'dart pub activate $cliName',
        [lightCyan, styleBold],
      );
      final styledCommandMessage = 'Run $styledCommand to update.';
      const boxLength = updateMessage.length + 4;
      final totalVersionsMessagePaddingLength =
          boxLength - latestVersion.length - cliVersion.length - 3;
      final versionsMessagePadding =
          ' ' * (totalVersionsMessagePaddingLength ~/ 2);
      stdout
        ..writeln()
        ..writeln(
          '''
┏${'━' * boxLength}┓
┃${' ' * boxLength}┃
┃  $styledUpdateMessage  ┃
┃$versionsMessagePadding$styledVersionsMessage$versionsMessagePadding${totalVersionsMessagePaddingLength.isOdd ? ' ' : ''}┃
┃  $styledCommandMessage  ┃
┃${' ' * boxLength}┃
┗${'━' * boxLength}┛
''',
        );
    }
  } catch (_) {}
}
