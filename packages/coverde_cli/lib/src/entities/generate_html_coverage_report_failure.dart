import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.generate_html_coverage_report_failure}
/// The interface for a failure that occurs when generating an HTML coverage
/// report.
/// {@endtemplate}
sealed class GenerateHtmlCoverageReportFailure extends CoverdeFailure {
  /// {@macro coverde_cli.generate_html_coverage_report_failure}
  const GenerateHtmlCoverageReportFailure();
}

/// An operation on a file.
enum GenerateHtmlCoverageReportFileOperation {
  /// The operation to create a file.
  create('create'),

  /// The operation to read a file.
  read('read'),

  /// The operation to write to a file.
  write('write'),
  ;

  const GenerateHtmlCoverageReportFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.generate_html_coverage_report_file_operation_failure}
/// The interface for a failure that occurs when performing a file operation
/// during HTML coverage report generation.
/// {@endtemplate}
sealed class GenerateHtmlCoverageReportFileOperationFailure
    extends GenerateHtmlCoverageReportFailure {
  /// {@macro coverde_cli.generate_html_coverage_report_file_operation_failure}
  const GenerateHtmlCoverageReportFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'create', 'write').
  final GenerateHtmlCoverageReportFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.generate_html_coverage_report_file_create_failure}
/// The interface for a failure that occurs when creating a file during HTML
/// coverage report generation.
/// {@endtemplate}
final class GenerateHtmlCoverageReportFileCreateFailure
    extends GenerateHtmlCoverageReportFileOperationFailure {
  /// Create a [GenerateHtmlCoverageReportFileCreateFailure] from a
  /// [FileSystemException].
  GenerateHtmlCoverageReportFileCreateFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: GenerateHtmlCoverageReportFileOperation.create,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.generate_html_coverage_report_file_read_failure}
/// The interface for a failure that occurs when reading a file during HTML
/// coverage report generation.
/// {@endtemplate}
final class GenerateHtmlCoverageReportFileReadFailure
    extends GenerateHtmlCoverageReportFileOperationFailure {
  /// Create a [GenerateHtmlCoverageReportFileReadFailure] from a
  /// [FileSystemException].
  GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: GenerateHtmlCoverageReportFileOperation.read,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.generate_html_coverage_report_file_write_failure}
/// The interface for a failure that occurs when writing to a file during HTML
/// coverage report generation.
/// {@endtemplate}
final class GenerateHtmlCoverageReportFileWriteFailure
    extends GenerateHtmlCoverageReportFileOperationFailure {
  /// Create a [GenerateHtmlCoverageReportFileWriteFailure] from a
  /// [FileSystemException].
  GenerateHtmlCoverageReportFileWriteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: GenerateHtmlCoverageReportFileOperation.write,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
