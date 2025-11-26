import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/coverde_command.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/optimize_tests/optimize_tests.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/utils/package_data.dart';
import 'package:mason_logger/mason_logger.dart';

/// {@template coverde_cli.coverde_command_runner}
/// The runner for the coverde command.
/// {@endtemplate}
class CoverdeCommandRunner extends CommandRunner<void> {
  /// {@macro coverde_cli.coverde_command_runner}
  CoverdeCommandRunner({
    Logger? logger,
  })  : _logger = logger ?? Logger(),
        super(
          packageName,
          'A set of commands that '
          'encapsulate coverage-related functionalities.',
        ) {
    addCommand(OptimizeTestsCommand(logger: _logger));
    addCommand(CheckCommand(logger: _logger));
    addCommand(FilterCommand(logger: _logger));
    addCommand(ReportCommand(logger: _logger));
    addCommand(RmCommand(logger: _logger));
    addCommand(ValueCommand(logger: _logger));
  }

  final Logger _logger;

  /// The commands that encapsulate actual functionality.
  Map<String, CoverdeCommand> get featureCommands => {
        for (final MapEntry(:key, :value) in super.commands.entries)
          if (value is CoverdeCommand) key: value,
      };
}
