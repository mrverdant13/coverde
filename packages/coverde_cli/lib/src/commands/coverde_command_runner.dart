import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:process/process.dart';

/// {@template coverde_cli.coverde_command_runner}
/// The runner for the coverde command.
/// {@endtemplate}
class CoverdeCommandRunner extends CommandRunner<void> {
  /// {@macro coverde_cli.coverde_command_runner}
  CoverdeCommandRunner({
    this.packageVersionManager,
    Logger? logger,
    ProcessManager? processManager,
  })  : logger = logger ?? Logger(), // coverage:ignore-line
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
    argParser.addOption(
      updateCheckOptionName,
      help: 'The update check mode to use.',
      allowed: UpdateCheckMode.values.map((mode) => mode.identifier),
      allowedHelp: {
        for (final mode in UpdateCheckMode.values) mode.identifier: mode.help,
      },
      defaultsTo: UpdateCheckMode.enabled.identifier,
    );
  }

  /// Option name for the update check mode.
  static const updateCheckOptionName = 'update-check';

  /// The logger for the command runner.
  final Logger logger;

  /// The process manager for the command runner.
  final ProcessManager processManager;

  /// The package version manager.
  final PackageVersionManager? packageVersionManager;

  /// The commands that encapsulate actual functionality.
  Iterable<CoverdeCommand> get featureCommands => {
        for (final MapEntry(:value) in super.commands.entries)
          if (value is CoverdeCommand) value,
      };

  @override
  void printUsage() {
    logger.write('$usage\n');
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    await super.runCommand(topLevelResults);
    final updateCheckMode = UpdateCheckMode.values.firstWhere(
      // It is safe to look up the update check mode by identifier because the
      // allowed values are validated by the args parser.
      (mode) =>
          mode.identifier == topLevelResults.option(updateCheckOptionName),
    );
    switch (updateCheckMode) {
      case UpdateCheckMode.disabled:
        return;
      case UpdateCheckMode.enabled:
        logger.level = Level.quiet;
      case UpdateCheckMode.enabledVerbose:
        logger.level = Level.verbose;
    }
    await packageVersionManager?.promptUpdate();
  }
}
