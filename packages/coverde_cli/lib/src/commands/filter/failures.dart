import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.filter_failure}
/// The interface for [FilterCommand] failures.
/// {@endtemplate}
sealed class CoverdeFilterFailure extends CoverdeFailure {
  /// {@macro coverde_cli.filter_failure}
  const CoverdeFilterFailure();
}

/// {@template coverde_cli.filter_invalid_input_failure}
/// The interface for [FilterCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeFilterInvalidInputFailure extends CoverdeFilterFailure {
  /// {@macro coverde_cli.filter_invalid_input_failure}
  const CoverdeFilterInvalidInputFailure({
    required this.usageMessage,
  });

  /// The description of the invalid input.
  String get invalidInputDescription;

  /// The [FilterCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.filter_invalid_regex_pattern_failure}
/// A [FilterCommand] failure that indicates that an invalid regex pattern was
/// provided.
/// {@endtemplate}
final class CoverdeFilterInvalidRegexPatternFailure
    extends CoverdeFilterInvalidInputFailure {
  /// {@macro coverde_cli.filter_invalid_regex_pattern_failure}
  const CoverdeFilterInvalidRegexPatternFailure({
    required super.usageMessage,
    required this.invalidRegexPattern,
    required this.exception,
  });

  /// The invalid regex pattern.
  final String invalidRegexPattern;

  /// The underlying regex pattern parsing exception.
  final FormatException exception;

  @override
  String get invalidInputDescription =>
      'Invalid regex pattern: `$invalidRegexPattern`.\n'
      '${exception.message}';
}

/// {@template coverde_cli.filter_trace_file_not_found_failure}
/// A [FilterCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeFilterTraceFileNotFoundFailure extends CoverdeFilterFailure {
  /// {@macro coverde_cli.filter_trace_file_not_found_failure}
  const CoverdeFilterTraceFileNotFoundFailure({
    required this.traceFilePath,
  });

  /// The path to the trace file.
  final String traceFilePath;

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// An operation on a file.
enum CoverdeFilterFileOperation {
  /// The operation to write to a file.
  write('write'),
  ;

  const CoverdeFilterFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.filter_file_operation_failure}
/// The interface for [FilterCommand] failures that indicates that a file system
/// operation on a file failed.
/// {@endtemplate}
sealed class CoverdeFilterFileOperationFailure extends CoverdeFilterFailure {
  /// {@macro coverde_cli.filter_file_operation_failure}
  const CoverdeFilterFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'write').
  final CoverdeFilterFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.filter_file_write_failure}
/// A [FilterCommand] failure that indicates that a file write operation failed.
/// {@endtemplate}
final class CoverdeFilterFileWriteFailure
    extends CoverdeFilterFileOperationFailure {
  /// Create a [CoverdeFilterFileWriteFailure] from a [FileSystemException].
  CoverdeFilterFileWriteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeFilterFileOperation.write,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// An operation on a directory.
enum CoverdeFilterDirectoryOperation {
  /// The operation to create a directory.
  create('create'),
  ;

  const CoverdeFilterDirectoryOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.filter_directory_operation_failure}
/// The interface for [FilterCommand] failures that indicates that a file system
/// operation on a directory failed.
/// {@endtemplate}
sealed class CoverdeFilterDirectoryOperationFailure
    extends CoverdeFilterFailure {
  /// {@macro coverde_cli.filter_directory_operation_failure}
  const CoverdeFilterDirectoryOperationFailure({
    required this.directoryPath,
    required this.operation,
    required this.errorMessage,
  });

  /// The directory path where the operation failed.
  final String directoryPath;

  /// The operation that failed (e.g., 'create').
  final CoverdeFilterDirectoryOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} directory at `$directoryPath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.filter_directory_create_failure}
/// A [FilterCommand] failure that indicates that a directory creation
/// operation failed.
/// {@endtemplate}
final class CoverdeFilterDirectoryCreateFailure
    extends CoverdeFilterDirectoryOperationFailure {
  /// Create a [CoverdeFilterDirectoryCreateFailure] from a
  /// [FileSystemException].
  CoverdeFilterDirectoryCreateFailure.fromFileSystemException({
    required super.directoryPath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeFilterDirectoryOperation.create,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
