import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/optimize_tests/optimize_tests.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/utils/package_data.dart';
import 'package:io/ansi.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:universal_io/io.dart';

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

/// {@template coverde_cli.coverde_command_runner}
/// The runner for the coverde command.
/// {@endtemplate}
class CoverdeCommandRunner extends CommandRunner<void> {
  /// {@macro coverde_cli.coverde_command_runner}
  CoverdeCommandRunner()
      : super(
          packageName,
          'A set of commands that '
          'encapsulate coverage-related functionalities.',
        ) {
    addCommand(OptimizeTestsCommand());
    addCommand(CheckCommand());
    addCommand(FilterCommand());
    addCommand(ReportCommand());
    addCommand(RmCommand());
    addCommand(ValueCommand());
  }

  /// The commands that encapsulate actual functionality.
  Map<String, CoverdeCommand> get featureCommands => {
        for (final MapEntry(:key, :value) in super.commands.entries)
          if (value is CoverdeCommand) key: value,
      };
}

/// {@template coverde_cli.coverde_command}
/// A base coverde command.
/// {@endtemplate}
abstract class CoverdeCommand extends Command<void> {
  /// The parameters for the command.
  CoverdeCommandParams? get params => null;

  @override
  String get invocation {
    return switch (params) {
      CoverdeCommandParams(:final identifier) => super.invocation.replaceAll(
            '[arguments]',
            '[$identifier]',
          ),
      null => super.invocation.replaceAll(
            r'\w*[arguments]',
            '',
          ),
    };
  }
}

/// {@template coverde_cli.coverde_command_params}
/// The parameters for a [CoverdeCommand].
/// {@endtemplate}
class CoverdeCommandParams {
  /// {@macro coverde_cli.coverde_command_params}
  CoverdeCommandParams({
    required this.identifier,
    required this.description,
  });

  /// The identifier for the command parameters.
  final String identifier;

  /// The description for the command parameters.
  final String description;
}
