import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:process/process.dart';

/// {@template coverde_cli.coverde_command}
/// A base coverde command.
/// {@endtemplate}
abstract class CoverdeCommand extends Command<void> {
  /// {@macro coverde_cli.coverde_command}
  CoverdeCommand();

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
            r'\s*\[arguments\]',
            '',
          ),
    };
  }

  @override
  CoverdeCommandRunner get runner => super.runner! as CoverdeCommandRunner;

  /// The logger for the command.
  Logger get logger => runner.logger;

  /// The process manager for the command.
  ProcessManager get processManager => runner.processManager;
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
