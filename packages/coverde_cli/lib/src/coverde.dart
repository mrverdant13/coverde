import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde({
  required List<String> args,
  required Logger logger,
}) async {
  await CoverdeCommandRunner(logger: logger).run(args);
  await _checkUpdates(logger);
}

Future<void> _checkUpdates(Logger logger) async {
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
      logger
        ..info('')
        ..info(
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
