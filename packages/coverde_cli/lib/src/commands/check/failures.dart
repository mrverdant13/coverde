import 'package:coverde/coverde.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/reporting/models/coverage_document.dart';
import 'package:universal_io/io.dart';

/// {@template coverde_cli.check_failure}
/// The interface for [CheckCommand] failures.
/// {@endtemplate}
sealed class CoverdeCheckFailure extends CoverdeFailure {
  /// {@macro coverde_cli.check_failure}
  const CoverdeCheckFailure();
}

/// {@template coverde_cli.check_invalid_input_failure}
/// The interface for [CheckCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeCheckInvalidInputFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_invalid_input_failure}
  const CoverdeCheckInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [CheckCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.check_more_than_one_argument_failure}
/// A [CheckCommand] failure that indicates that more than one argument was
/// provided.
/// {@endtemplate}
final class CoverdeCheckMoreThanOneArgumentFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_more_than_one_argument_failure}
  const CoverdeCheckMoreThanOneArgumentFailure({required super.usageMessage})
    : super(
        invalidInputDescription:
            'Only one argument (minimum coverage threshold) is expected.',
      );
}

/// {@template coverde_cli.check_missing_minimum_coverage_threshold_failure}
/// A [CheckCommand] failure that indicates that the minimum coverage threshold
/// was not provided.
/// {@endtemplate}
final class CoverdeCheckMissingMinimumCoverageThresholdFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_missing_minimum_coverage_threshold_failure}
  const CoverdeCheckMissingMinimumCoverageThresholdFailure({
    required super.usageMessage,
  }) : super(invalidInputDescription: 'Missing minimum coverage threshold.');
}

/// {@template coverde_cli.check_invalid_minimum_coverage_threshold_failure}
/// A [CheckCommand] failure that indicates that the minimum coverage threshold
/// was provided but is invalid.
/// {@endtemplate}
final class CoverdeCheckInvalidMinimumCoverageThresholdFailure
    extends CoverdeCheckInvalidInputFailure {
  /// {@macro coverde_cli.check_invalid_minimum_coverage_threshold_failure}
  const CoverdeCheckInvalidMinimumCoverageThresholdFailure({
    required super.usageMessage,
  }) : super(
         invalidInputDescription:
             'Invalid minimum coverage threshold.\n'
             'It should be a positive number not greater than 100 '
             '[0.0, 100.0].',
       );
}

/// {@template coverde_cli.check_unknown_coverage_threshold_failure}
/// A [CheckCommand] failure that indicates that a named coverage threshold is
/// not defined in `coverde.yaml`.
/// {@endtemplate}
final class CoverdeCheckUnknownCoverageThresholdFailure
    extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_unknown_coverage_threshold_failure}
  const CoverdeCheckUnknownCoverageThresholdFailure({
    required this.thresholdName,
    required this.configPath,
    required this.availableThresholds,
  });

  /// The coverage threshold name that was not defined.
  final String thresholdName;

  /// The path to the config file that was consulted.
  final String configPath;

  /// The coverage threshold names defined in [configPath].
  final List<String> availableThresholds;

  @override
  String get readableMessage {
    final available =
        availableThresholds.isEmpty
            ? 'none'
            : availableThresholds.map((name) => '`$name`').join(', ');
    return '''
Unknown coverage threshold `$thresholdName` in `$configPath`.
Available thresholds: $available.
''';
  }
}

/// {@template coverde_cli.check_config_file_read_failure}
/// A [CheckCommand] failure that indicates that the config file could not be
/// read.
/// {@endtemplate}
final class CoverdeCheckConfigFileReadFailure extends CoverdeCheckFailure {
  /// Create a [CoverdeCheckConfigFileReadFailure] from a [FileSystemException].
  CoverdeCheckConfigFileReadFailure.fromFileSystemException({
    required this.configPath,
    required FileSystemException exception,
  }) : errorMessage = [
         exception.message,
         if (exception.osError case final osError?) osError.message,
       ].join('\n');

  /// The path to the config file.
  final String configPath;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to read config file at `$configPath`.\n$errorMessage';
}

/// {@template coverde_cli.check_invalid_config_file_failure}
/// A [CheckCommand] failure that indicates that the config file is invalid.
/// {@endtemplate}
final class CoverdeCheckInvalidConfigFileFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_invalid_config_file_failure}
  const CoverdeCheckInvalidConfigFileFailure({
    required this.configPath,
    required this.failure,
  });

  /// The path to the config file.
  final String configPath;

  /// The underlying failure.
  final CoverdeConfigFromYamlFailure failure;

  @override
  String get readableMessage => [
    'Invalid config file at `$configPath`.',
    ...switch (failure) {
      CoverdeConfigFromYamlInvalidYamlFailure(:final yamlException) => [
        'Invalid YAML: ${yamlException.message}.',
      ],
      CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        :final key,
        :final expectedType,
        :final value,
      ) =>
        [
          'Invalid YAML member type.',
          'Key: `${key ?? '<root>'}`.',
          'Expected type: `$expectedType`.',
          'Value: `$value`.',
        ],
      CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
        :final key,
        :final value,
        :final hint,
      ) =>
        [
          'Invalid YAML member value.',
          'Key: `${key ?? '<root>'}`.',
          if (hint != null) 'Hint: $hint.',
          'Value: `$value`.',
        ],
      CoverdeConfigFromYamlUnknownPresetFailure(
        :final unknownPreset,
        :final availablePresets,
      ) =>
        [
          'Unknown preset: `$unknownPreset`.',
          'Available presets:',
          for (final preset in availablePresets) '- `$preset`',
        ],
      CoverdeConfigFromYamlPresetCycleFailure(:final cycle) => [
        'Preset cycle detected: ${cycle.join(' -> ')}.',
      ],
      CoverdeConfigFromYamlInvalidCoveragePercentageFailure(
        :final key,
        :final invalidReferences,
      ) =>
        [
          'Invalid coverage percentage.',
          'Key: `$key`.',
          'Coverage values must be between 0 and 100.',
          'Invalid values: ${invalidReferences.join(', ')}.',
        ],
    },
  ].join('\n');
}

/// {@template coverde_cli.check_invalid_trace_file_failure}
/// The interface for [CheckCommand] failures that indicates that an invalid
/// trace file was provided.
/// {@endtemplate}
sealed class CoverdeCheckInvalidTraceFileFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_invalid_trace_file_failure}
  const CoverdeCheckInvalidTraceFileFailure({required this.traceFilePath});

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.check_trace_file_not_found_failure}
/// A [CheckCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeCheckTraceFileNotFoundFailure
    extends CoverdeCheckInvalidTraceFileFailure {
  /// {@macro coverde_cli.check_trace_file_not_found_failure}
  const CoverdeCheckTraceFileNotFoundFailure({required super.traceFilePath});

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.check_empty_trace_file_failure}
/// A [CheckCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeCheckEmptyTraceFileFailure
    extends CoverdeCheckInvalidTraceFileFailure {
  /// {@macro coverde_cli.check_empty_trace_file_failure}
  const CoverdeCheckEmptyTraceFileFailure({required super.traceFilePath});

  @override
  String get readableMessage =>
      'No coverage data found in the trace file located at `$traceFilePath`.';
}

/// {@template coverde_cli.check_trace_file_read_failure}
/// A [CheckCommand] failure that indicates that a trace file read operation
/// failed.
/// {@endtemplate}
final class CoverdeCheckTraceFileReadFailure
    extends CoverdeCheckInvalidTraceFileFailure {
  /// Create a [CoverdeCheckTraceFileReadFailure] from a [FileSystemException].
  CoverdeCheckTraceFileReadFailure.fromFileSystemException({
    required super.traceFilePath,
    required FileSystemException exception,
  }) : errorMessage = [
         exception.message,
         if (exception.osError case final osError?) osError.message,
       ].join('\n');

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to read trace file at `$traceFilePath`.\n$errorMessage';
}

/// {@template coverde_cli.check_coverage_below_minimum_failure}
/// A [CheckCommand] failure that indicates that the coverage value is below the
/// minimum coverage threshold.
/// {@endtemplate}
final class CoverdeCheckCoverageBelowMinimumFailure
    extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_coverage_below_minimum_failure}
  const CoverdeCheckCoverageBelowMinimumFailure({
    required this.minimumCoverage,
    required this.traceFile,
  });

  /// The minimum coverage threshold.
  final double minimumCoverage;

  /// The actual coverage value.
  double get actualCoverage => traceFile.lineRate!;

  /// The trace file.
  final CoverageDocument traceFile;

  @override
  String get readableMessage => '''
The minimum coverage value has not been reached.
Expected min coverage: ${minimumCoverage.toStringAsFixed(2)} %.
Actual coverage: ${traceFile.lineRate!.toStringAsFixed(2)} %.
''';
}

/// {@template coverde_cli.check_no_line_coverage_failure}
/// A [CheckCommand] failure that indicates that the trace has no line coverage.
/// {@endtemplate}
final class CoverdeCheckNoLineCoverageFailure extends CoverdeCheckFailure {
  /// {@macro coverde_cli.check_no_line_coverage_failure}
  const CoverdeCheckNoLineCoverageFailure({required this.traceFilePath});

  /// The trace file that has no line coverage.
  final String traceFilePath;

  @override
  String get readableMessage =>
      'Trace file at `$traceFilePath` has no line coverage to check.';
}
