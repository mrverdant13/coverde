import 'package:coverde/coverde.dart';
import 'package:coverde/src/features/coverde_config/coverde_config.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.transform_failure}
/// The interface for [TransformCommand] failures.
/// {@endtemplate}
sealed class CoverdeTransformFailure extends CoverdeFailure {
  /// {@macro coverde_cli.transform_failure}
  const CoverdeTransformFailure();
}

/// {@template coverde_cli.transform_invalid_config_file_failure}
/// A [TransformCommand] failure that indicates that the config file is invalid.
/// {@endtemplate}
final class CoverdeTransformInvalidConfigFileFailure
    extends CoverdeTransformFailure {
  /// {@macro coverde_cli.transform_invalid_config_file_failure}
  const CoverdeTransformInvalidConfigFileFailure({
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
            :final value
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
            :final hint
          ) =>
            [
              'Invalid YAML member value.',
              'Key: `${key ?? '<root>'}`.',
              if (hint != null) 'Hint: $hint.',
              'Value: `$value`.',
            ],
          CoverdeConfigFromYamlUnknownPresetFailure(
            :final unknownPreset,
            :final availablePresets
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
            :final invalidReferences
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

/// {@template coverde_cli.transform_invalid_transform_cli_option_failure}
/// The interface for [TransformCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
final class CoverdeTransformInvalidTransformCliOptionFailure
    extends CoverdeTransformFailure {
  /// {@macro coverde_cli.transform_invalid_transform_cli_option_failure}
  const CoverdeTransformInvalidTransformCliOptionFailure({
    required this.failure,
  });

  /// The underlying failure.
  final TransformationFromCliOptionFailure failure;

  @override
  String get readableMessage => [
        'Invalid transformation CLI option.',
        ...switch (failure) {
          TransformationFromCliOptionUnknownPresetFailure(
            :final unknownPreset,
            :final availablePresets,
          ) =>
            [
              'Unknown preset: `$unknownPreset`.',
              'Available presets:',
              for (final preset in availablePresets) '- `$preset`',
            ],
          TransformationFromCliOptionUnsupportedTransformationFailure(
            :final unsupportedTransformation,
          ) =>
            [
              'Unsupported transformation: `$unsupportedTransformation`.',
            ],
          TransformationFromCliOptionInvalidRegexPatternFailure(
            :final transformationIdentifier,
            :final regex,
          ) =>
            [
              'Transformation: `$transformationIdentifier`.',
              'Invalid regex pattern: `$regex`.',
            ],
          TransformationFromCliOptionInvalidGlobPatternFailure(
            :final transformationIdentifier,
            :final glob,
          ) =>
            [
              'Transformation: `$transformationIdentifier`.',
              'Invalid glob pattern: `$glob`.',
            ],
          TransformationFromCliOptionInvalidNumericComparisonFailure(
            :final transformationIdentifier,
            :final comparison,
          ) =>
            [
              'Transformation: `$transformationIdentifier`.',
              'Invalid numeric comparison: `$comparison`.',
            ],
          TransformationFromCliOptionInvalidCoveragePercentageFailure(
            :final transformationIdentifier,
            :final invalidReferences,
          ) =>
            [
              'Transformation: `$transformationIdentifier`.',
              'Coverage values must be between 0 and 100.',
              'Invalid values: ${invalidReferences.join(', ')}.',
            ],
        },
      ].join('\n');
}

/// {@template coverde_cli.transform_trace_file_not_found_failure}
/// A [TransformCommand] failure that indicates that the trace file was not
/// found.
/// {@endtemplate}
final class CoverdeTransformTraceFileNotFoundFailure
    extends CoverdeTransformFailure {
  /// {@macro coverde_cli.transform_trace_file_not_found_failure}
  const CoverdeTransformTraceFileNotFoundFailure({
    required this.traceFilePath,
  });

  /// The path to the trace file.
  final String traceFilePath;

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// An operation on a file.
enum CoverdeTransformFileOperation {
  /// The operation to read from a file.
  read('read'),

  /// The operation to write to a file.
  write('write'),
  ;

  const CoverdeTransformFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.transform_file_operation_failure}
/// The interface for [TransformCommand] failures that indicates that a file
/// system operation on a file failed.
/// {@endtemplate}
sealed class CoverdeTransformFileOperationFailure
    extends CoverdeTransformFailure {
  /// {@macro coverde_cli.transform_file_operation_failure}
  const CoverdeTransformFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'write').
  final CoverdeTransformFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.transform_file_read_failure}
/// A [TransformCommand] failure that indicates that a file read operation
/// failed.
/// {@endtemplate}
final class CoverdeTransformFileReadFailure
    extends CoverdeTransformFileOperationFailure {
  /// Create a [CoverdeTransformFileReadFailure] from a [FileSystemException].
  CoverdeTransformFileReadFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeTransformFileOperation.read,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.transform_file_write_failure}
/// A [TransformCommand] failure that indicates that a file write operation
/// failed.
/// {@endtemplate}
final class CoverdeTransformFileWriteFailure
    extends CoverdeTransformFileOperationFailure {
  /// Create a [CoverdeTransformFileWriteFailure] from a [FileSystemException].
  CoverdeTransformFileWriteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeTransformFileOperation.write,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// An operation on a directory.
enum CoverdeTransformDirectoryOperation {
  /// The operation to create a directory.
  create('create'),
  ;

  const CoverdeTransformDirectoryOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.transform_directory_operation_failure}
/// The interface for [TransformCommand] failures that indicates that a file
/// system operation on a directory failed.
/// {@endtemplate}
sealed class CoverdeTransformDirectoryOperationFailure
    extends CoverdeTransformFailure {
  /// {@macro coverde_cli.transform_directory_operation_failure}
  const CoverdeTransformDirectoryOperationFailure({
    required this.directoryPath,
    required this.operation,
    required this.errorMessage,
  });

  /// The directory path where the operation failed.
  final String directoryPath;

  /// The operation that failed (e.g., 'create').
  final CoverdeTransformDirectoryOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} directory at `$directoryPath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.transform_directory_create_failure}
/// A [TransformCommand] failure that indicates that a directory creation
/// operation failed.
/// {@endtemplate}
final class CoverdeTransformDirectoryCreateFailure
    extends CoverdeTransformDirectoryOperationFailure {
  /// Create a [CoverdeTransformDirectoryCreateFailure] from a
  /// [FileSystemException].
  CoverdeTransformDirectoryCreateFailure.fromFileSystemException({
    required super.directoryPath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeTransformDirectoryOperation.create,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
