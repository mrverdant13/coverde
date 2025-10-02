import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/check.dart';
import 'package:coverde/src/commands/coverde_command.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/commands/optimize_tests/optimize_tests.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/utils/package_data.dart';

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
