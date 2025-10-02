import 'package:coverde/src/commands/coverde_command_runner.dart';
import 'package:coverde/src/utils/package_data.dart';
import 'package:io/ansi.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:universal_io/io.dart';

export 'coverde_command.dart';
export 'coverde_command_runner.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde(List<String> args) async {
  await CoverdeCommandRunner().run(args);
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
