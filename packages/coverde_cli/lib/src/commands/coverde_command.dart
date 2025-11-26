import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// {@template coverde_cli.coverde_command}
/// A base coverde command.
/// {@endtemplate}
abstract class CoverdeCommand extends Command<void> {
  /// {@macro coverde_cli.coverde_command}
  CoverdeCommand({
    Logger? logger,
  }) : logger = logger ?? Logger();

  /// Shared logger instance for commands.
  final Logger logger;

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
