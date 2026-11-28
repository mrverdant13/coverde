import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/check/render_check.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// {@template check_cmd}
/// A command to check the minimum coverage value from a trace file.
/// {@endtemplate}
class CheckCommand extends CoverdeCommand {
  /// {@macro check_cmd}
  CheckCommand() {
    argParser
      ..addOption(
        inputOptionName,
        abbr: inputOptionAbbreviation,
        help: '''
Trace file used for the coverage check.''',
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        configOptionName,
        help: '''
Path to the coverde.yaml file.

A number threshold does not read the default file.
A name threshold, and any explicit path, reads that file.''',
        defaultsTo: _configFileName,
      );
  }

  /// Option name for the trace file whose coverage value should be checked.
  @visibleForTesting
  static const inputOptionName = 'input';

  /// Option abbreviation for the trace file whose coverage value should be
  /// checked.
  @visibleForTesting
  static const inputOptionAbbreviation = 'i';

  /// Option name for the configuration file.
  @visibleForTesting
  static const configOptionName = 'config';

  /// The name of the configuration file consulted for named thresholds.
  static const _configFileName = 'coverde.yaml';

  @override
  String get description => '''
Check the coverage value (%) computed from a trace file.

The unique argument is a coverage threshold.
It is either a number between 0 and 100, or the name of a `coverage` entry in coverde.yaml.''';

  @override
  String get name => 'check';

  @override
  CoverdeCommandParams get params => CoverdeCommandParams(
    identifier: 'min-coverage',
    description:
        'A number between 0 and 100, or the name of a `coverage` entry '
        'in coverde.yaml.',
  );

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final filePath = p.absolute(argResults.option(inputOptionName)!);
    final args = argResults.rest;
    if (args.length > 1) {
      throw CoverdeCheckMoreThanOneArgumentFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    final coverageThresholdStr = args.firstOrNull;
    if (coverageThresholdStr == null) {
      throw CoverdeCheckMissingMinimumCoverageThresholdFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    final coverageThreshold = _resolveCoverageThreshold(coverageThresholdStr);

    if (!FileSystemEntity.isFileSync(filePath)) {
      throw CoverdeCheckTraceFileNotFoundFailure(traceFilePath: filePath);
    }
    final file = File(filePath);

    final CoverageDocument document;
    try {
      document = await CoverageDocument.parseStreaming(file);
    } on FileSystemException catch (exception) {
      throw CoverdeCheckTraceFileReadFailure.fromFileSystemException(
        traceFilePath: filePath,
        exception: exception,
      );
    }

    if (document.isEmpty) {
      throw CoverdeCheckEmptyTraceFileFailure(traceFilePath: filePath);
    }

    logger.write(await renderCheckReport(document: document));

    final lineRate = document.lineRate;
    if (lineRate == null) {
      throw CoverdeCheckNoLineCoverageFailure(traceFilePath: filePath);
    }
    if (lineRate < coverageThreshold) {
      throw CoverdeCheckCoverageBelowMinimumFailure(
        minimumCoverage: coverageThreshold,
        document: document,
      );
    }
  }

  /// Resolves [rawThreshold] as a numeric one-off or a `coverde.yaml` name.
  ///
  /// A number does not read the default file. A name does. An explicit
  /// `--config` is read either way.
  double _resolveCoverageThreshold(String rawThreshold) {
    final argResults = this.argResults!;
    final configPath = p.absolute(argResults.option(configOptionName)!);
    final configIsExplicit = argResults.wasParsed(configOptionName);
    final parsedThreshold = double.tryParse(rawThreshold);
    if (parsedThreshold != null) {
      if (!_isAcceptableCoverageThreshold(parsedThreshold)) {
        throw CoverdeCheckInvalidMinimumCoverageThresholdFailure(
          usageMessage: usageWithoutDescription,
        );
      }
      if (configIsExplicit) {
        _readCoverdeConfig(configPath);
      }
      return parsedThreshold;
    }

    final config = _readCoverdeConfig(configPath);
    final threshold = config.coverageThresholds[rawThreshold];
    if (threshold == null) {
      throw CoverdeCheckUnknownCoverageThresholdFailure(
        thresholdName: rawThreshold,
        configPath: configPath,
        availableThresholds: config.coverageThresholds.keys.toList()..sort(),
      );
    }
    logger.info(
      'Using coverage threshold `$rawThreshold` '
      '(${threshold.toStringAsFixed(2)}%) from `$configPath`.',
    );
    return threshold;
  }

  CoverdeConfig _readCoverdeConfig(String configPath) {
    if (!FileSystemEntity.isFileSync(configPath)) {
      throw CoverdeCheckConfigFileNotFoundFailure(configPath: configPath);
    }
    final String rawConfig;
    try {
      rawConfig = File(configPath).readAsStringSync();
    } on FileSystemException catch (exception) {
      throw CoverdeCheckConfigFileReadFailure.fromFileSystemException(
        configPath: configPath,
        exception: exception,
      );
    }
    try {
      return CoverdeConfig.fromYaml(
        rawConfig,
        baseDirectory: p.dirname(configPath),
      );
    } on CoverdeConfigFromYamlFailure catch (failure, stackTrace) {
      Error.throwWithStackTrace(
        CoverdeCheckInvalidConfigFileFailure(
          configPath: configPath,
          failure: failure,
        ),
        stackTrace,
      );
    }
  }
}

/// Whether [value] is a finite percentage in the inclusive range 0-100.
bool _isAcceptableCoverageThreshold(double value) {
  return value.isFinite && value >= 0 && value <= 100;
}
