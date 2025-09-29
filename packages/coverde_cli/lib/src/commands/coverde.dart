import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/optimize_tests/optimize_tests.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/utils/package_data.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:universal_io/io.dart';

@internal
final runner = CommandRunner<void>(
  packageName,
  'A set of commands that encapsulate coverage-related functionalities.',
) //
  ..addCommand(OptimizeTestsCommand())
  ..addCommand(CheckCommand())
  ..addCommand(FilterCommand())
  ..addCommand(ReportCommand())
  ..addCommand(RmCommand())
  ..addCommand(ValueCommand());

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde(List<String> args) async {
  await runner.run(args);
  await _checkUpdates();
}

Future<void> _checkUpdates() async {
  try {
    final updater = PubUpdater();
    final latestVersion = await updater.getLatestVersion(packageName);
    final isUpToDate = latestVersion == packageVersion;
    if (!isUpToDate) {
      const updateMessage = 'A new version of `$packageName` is available!';
      final styledUpdateMessage = lightYellow.wrap(updateMessage);
      final styledVersionsMessage = '''
${lightGray.wrap(packageVersion)} \u2192 ${lightGreen.wrap(latestVersion)}''';
      final styledCommand = wrapWith(
        'dart pub activate $packageName',
        [lightCyan, styleBold],
      );
      final styledCommandMessage = 'Run $styledCommand to update.';
      const boxLength = updateMessage.length + 4;
      final totalVersionsMessagePaddingLength =
          boxLength - latestVersion.length - packageVersion.length - 3;
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
  } on Object catch (_) {}
}
