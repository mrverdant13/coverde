import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:process/process.dart';

/// {@template coverde_cli.coverde_command_runner}
/// The runner for the coverde command.
/// {@endtemplate}
class CoverdeCommandRunner extends CommandRunner<void> {
  /// {@macro coverde_cli.coverde_command_runner}
  CoverdeCommandRunner({
    Logger? logger,
    ProcessManager? processManager,
  })  : logger = logger ?? Logger(),
        processManager = processManager ?? const LocalProcessManager(),
        super(
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

  /// The logger for the command runner.
  final Logger logger;

  /// The process manager for the command runner.
  final ProcessManager processManager;

  /// The commands that encapsulate actual functionality.
  Iterable<CoverdeCommand> get featureCommands => {
        for (final MapEntry(:value) in super.commands.entries)
          if (value is CoverdeCommand) value,
      };
}
