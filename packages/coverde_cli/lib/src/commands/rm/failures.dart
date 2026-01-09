import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.rm_failure}
/// The interface for [RmCommand] failures.
/// {@endtemplate}
sealed class CoverdeRmFailure extends CoverdeFailure {
  /// {@macro coverde_cli.rm_failure}
  const CoverdeRmFailure();
}

/// {@template coverde_cli.rm_invalid_input_failure}
/// The interface for [RmCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeRmInvalidInputFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_invalid_input_failure}
  const CoverdeRmInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [RmCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.rm_missing_paths_failure}
/// A [RmCommand] failure that indicates that no paths were provided.
/// {@endtemplate}
final class CoverdeRmMissingPathsFailure extends CoverdeRmInvalidInputFailure {
  /// {@macro coverde_cli.rm_missing_paths_failure}
  const CoverdeRmMissingPathsFailure({
    required super.usageMessage,
  }) : super(
          invalidInputDescription:
              'A set of file and/or directory paths should be provided.',
        );
}

/// {@template coverde_cli.rm_element_not_found_failure}
/// A [RmCommand] failure that indicates that an element was not found when
/// absence is not accepted.
/// {@endtemplate}
final class CoverdeRmElementNotFoundFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_element_not_found_failure}
  const CoverdeRmElementNotFoundFailure({
    required this.elementPath,
  });

  /// The path to the element that was not found.
  final String elementPath;

  @override
  String get readableMessage => 'The <$elementPath> element does not exist.';
}

/// An operation on a file.
enum CoverdeRmFileOperation {
  /// The operation to delete a file.
  delete('delete'),
  ;

  const CoverdeRmFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.rm_file_operation_failure}
/// The interface for [RmCommand] failures that indicates that a file system
/// operation on a file failed.
/// {@endtemplate}
sealed class CoverdeRmFileOperationFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_file_operation_failure}
  const CoverdeRmFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'delete').
  final CoverdeRmFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.rm_file_delete_failure}
/// A [RmCommand] failure that indicates that a file deletion operation failed.
/// {@endtemplate}
final class CoverdeRmFileDeleteFailure extends CoverdeRmFileOperationFailure {
  /// Create a [CoverdeRmFileDeleteFailure] from a [FileSystemException].
  CoverdeRmFileDeleteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeRmFileOperation.delete,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// An operation on a directory.
enum CoverdeRmDirectoryOperation {
  /// The operation to delete a directory.
  delete('delete'),
  ;

  const CoverdeRmDirectoryOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.rm_directory_operation_failure}
/// The interface for [RmCommand] failures that indicates that a file system
/// operation on a directory failed.
/// {@endtemplate}
sealed class CoverdeRmDirectoryOperationFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_directory_operation_failure}
  const CoverdeRmDirectoryOperationFailure({
    required this.directoryPath,
    required this.operation,
    required this.errorMessage,
  });

  /// The directory path where the operation failed.
  final String directoryPath;

  /// The operation that failed (e.g., 'delete').
  final CoverdeRmDirectoryOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} directory at `$directoryPath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.rm_directory_delete_failure}
/// A [RmCommand] failure that indicates that a directory deletion operation
/// failed.
/// {@endtemplate}
final class CoverdeRmDirectoryDeleteFailure
    extends CoverdeRmDirectoryOperationFailure {
  /// Create a [CoverdeRmDirectoryDeleteFailure] from a [FileSystemException].
  CoverdeRmDirectoryDeleteFailure.fromFileSystemException({
    required super.directoryPath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeRmDirectoryOperation.delete,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
