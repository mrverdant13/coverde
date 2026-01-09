import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.optimize_tests_failure}
/// The interface for [OptimizeTestsCommand] failures.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsFailure extends CoverdeFailure {
  /// {@macro coverde_cli.optimize_tests_failure}
  const CoverdeOptimizeTestsFailure();
}

/// {@template coverde_cli.optimize_tests_invalid_input_failure}
/// The interface for [OptimizeTestsCommand] failures that indicates that an
/// invalid input was provided.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsInvalidInputFailure
    extends CoverdeOptimizeTestsFailure {
  /// {@macro coverde_cli.optimize_tests_invalid_input_failure}
  const CoverdeOptimizeTestsInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [OptimizeTestsCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.optimize_tests_pubspec_not_found_failure}
/// A [OptimizeTestsCommand] failure that indicates that the pubspec.yaml file
/// was not found.
/// {@endtemplate}
final class CoverdeOptimizeTestsPubspecNotFoundFailure
    extends CoverdeOptimizeTestsInvalidInputFailure {
  /// {@macro coverde_cli.optimize_tests_pubspec_not_found_failure}
  const CoverdeOptimizeTestsPubspecNotFoundFailure({
    required super.usageMessage,
    required this.projectDirPath,
  }) : super(
          invalidInputDescription:
              'No pubspec.yaml file found in $projectDirPath.',
        );

  /// The project directory path.
  final String projectDirPath;
}

/// An operation on a file.
enum CoverdeOptimizeTestsFileOperation {
  /// The operation to read from a file.
  read('read'),

  /// The operation to write to a file.
  write('write'),

  /// The operation to delete a file.
  delete('delete'),
  ;

  const CoverdeOptimizeTestsFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.optimize_tests_file_operation_failure}
/// The interface for [OptimizeTestsCommand] failures that indicates that a file
/// system operation on a file failed.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsFileOperationFailure
    extends CoverdeOptimizeTestsFailure {
  /// {@macro coverde_cli.optimize_tests_file_operation_failure}
  const CoverdeOptimizeTestsFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'read', 'write', 'delete').
  final CoverdeOptimizeTestsFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.optimize_tests_file_read_failure}
/// A [OptimizeTestsCommand] failure that indicates that a file read operation
/// failed.
/// {@endtemplate}
final class CoverdeOptimizeTestsFileReadFailure
    extends CoverdeOptimizeTestsFileOperationFailure {
  /// Create a [CoverdeOptimizeTestsFileReadFailure] from a
  /// [FileSystemException].
  CoverdeOptimizeTestsFileReadFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeOptimizeTestsFileOperation.read,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.optimize_tests_file_write_failure}
/// A [OptimizeTestsCommand] failure that indicates that a file write operation
/// failed.
/// {@endtemplate}
final class CoverdeOptimizeTestsFileWriteFailure
    extends CoverdeOptimizeTestsFileOperationFailure {
  /// Create a [CoverdeOptimizeTestsFileWriteFailure] from a
  /// [FileSystemException].
  CoverdeOptimizeTestsFileWriteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeOptimizeTestsFileOperation.write,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.optimize_tests_file_delete_failure}
/// A [OptimizeTestsCommand] failure that indicates that a file
/// deletion operation failed.
/// {@endtemplate}
final class CoverdeOptimizeTestsFileDeleteFailure
    extends CoverdeOptimizeTestsFileOperationFailure {
  /// Create a [CoverdeOptimizeTestsFileDeleteFailure] from a
  /// [FileSystemException].
  CoverdeOptimizeTestsFileDeleteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeOptimizeTestsFileOperation.delete,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// An operation on a directory.
enum CoverdeOptimizeTestsDirectoryOperation {
  /// The operation to list a directory.
  list('list'),

  /// The operation to create a directory.
  create('create'),
  ;

  const CoverdeOptimizeTestsDirectoryOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.optimize_tests_directory_operation_failure}
/// The interface for [OptimizeTestsCommand] failures that indicates that a file
/// system operation on a directory failed.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsDirectoryOperationFailure
    extends CoverdeOptimizeTestsFailure {
  /// {@macro coverde_cli.optimize_tests_directory_operation_failure}
  const CoverdeOptimizeTestsDirectoryOperationFailure({
    required this.directoryPath,
    required this.operation,
    required this.errorMessage,
  });

  /// The directory path where the operation failed.
  final String directoryPath;

  /// The operation that failed (e.g., 'list', 'create').
  final CoverdeOptimizeTestsDirectoryOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} directory at `$directoryPath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.optimize_tests_directory_list_failure}
/// A [OptimizeTestsCommand] failure that indicates that a directory listing
/// operation failed.
/// {@endtemplate}
final class CoverdeOptimizeTestsDirectoryListFailure
    extends CoverdeOptimizeTestsDirectoryOperationFailure {
  /// Create a [CoverdeOptimizeTestsDirectoryListFailure] from a
  /// [FileSystemException].
  CoverdeOptimizeTestsDirectoryListFailure.fromFileSystemException({
    required super.directoryPath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeOptimizeTestsDirectoryOperation.list,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.optimize_tests_directory_create_failure}
/// A [OptimizeTestsCommand] failure that indicates that a directory creation
/// operation failed.
/// {@endtemplate}
final class CoverdeOptimizeTestsDirectoryCreateFailure
    extends CoverdeOptimizeTestsDirectoryOperationFailure {
  /// Create a [CoverdeOptimizeTestsDirectoryCreateFailure] from a
  /// [FileSystemException].
  CoverdeOptimizeTestsDirectoryCreateFailure.fromFileSystemException({
    required super.directoryPath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeOptimizeTestsDirectoryOperation.create,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
