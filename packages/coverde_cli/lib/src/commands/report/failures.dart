import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.report_failure}
/// The interface for [ReportCommand] failures.
/// {@endtemplate}
sealed class CoverdeReportFailure extends CoverdeFailure {
  /// {@macro coverde_cli.report_failure}
  const CoverdeReportFailure();
}

/// {@template coverde_cli.report_invalid_input_failure}
/// The interface for [ReportCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeReportInvalidInputFailure extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_invalid_input_failure}
  const CoverdeReportInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [ReportCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.report_invalid_medium_threshold_failure}
/// A [ReportCommand] failure that indicates that an invalid medium threshold
/// was provided.
/// {@endtemplate}
final class CoverdeReportInvalidMediumThresholdFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_medium_threshold_failure}
  const CoverdeReportInvalidMediumThresholdFailure({
    required super.usageMessage,
    required this.rawValue,
  }) : super(
          invalidInputDescription: 'Invalid medium threshold: `$rawValue`.\n'
              'It should be a positive number not greater than 100 '
              '[0.0, 100.0].',
        );

  /// The invalid medium value, if any.
  final String? rawValue;
}

/// {@template coverde_cli.report_invalid_high_threshold_failure}
/// A [ReportCommand] failure that indicates that an invalid high threshold
/// was provided.
/// {@endtemplate}
final class CoverdeReportInvalidHighThresholdFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_high_threshold_failure}
  const CoverdeReportInvalidHighThresholdFailure({
    required super.usageMessage,
    required this.rawValue,
  }) : super(
          invalidInputDescription: 'Invalid high threshold: `$rawValue`.\n'
              'It should be a positive number not greater than 100 '
              '[0.0, 100.0].',
        );

  /// The invalid high value, if any.
  final String? rawValue;
}

/// {@template coverde_cli.report_invalid_threshold_relationship_failure}
/// A [ReportCommand] failure that indicates that the threshold relationship
/// is invalid (medium >= high).
/// {@endtemplate}
final class CoverdeReportInvalidThresholdRelationshipFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_invalid_threshold_relationship_failure}
  const CoverdeReportInvalidThresholdRelationshipFailure({
    required super.usageMessage,
    required this.mediumValue,
    required this.highValue,
  }) : super(
          invalidInputDescription:
              'Medium threshold ($mediumValue) must be less than '
              'high threshold ($highValue).',
        );

  /// The medium threshold value.
  final double mediumValue;

  /// The high threshold value.
  final double highValue;
}

/// {@template coverde_cli.report_invalid_trace_file_failure}
/// The interface for [ReportCommand] failures that indicates that an invalid
/// trace file was provided.
/// {@endtemplate}
sealed class CoverdeReportInvalidTraceFileFailure extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_invalid_trace_file_failure}
  const CoverdeReportInvalidTraceFileFailure({
    required this.traceFilePath,
  });

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.report_trace_file_not_found_failure}
/// A [ReportCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeReportTraceFileNotFoundFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_trace_file_not_found_failure}
  const CoverdeReportTraceFileNotFoundFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.report_empty_trace_file_failure}
/// A [ReportCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeReportEmptyTraceFileFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_empty_trace_file_failure}
  const CoverdeReportEmptyTraceFileFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage =>
      'No coverage data found in the trace file at `$traceFilePath`.';
}

/// An operation on a file.
enum CoverdeReportFileOperation {
  /// The operation to create a file.
  create('create'),

  /// The operation to read a file.
  read('read'),

  /// The operation to write to a file.
  write('write'),
  ;

  const CoverdeReportFileOperation(this.name);

  /// The name of the operation.
  final String name;
}

/// {@template coverde_cli.report_file_operation_failure}
/// The interface for [ReportCommand] failures that indicates that a file
/// system operation on a file failed.
/// {@endtemplate}
sealed class CoverdeReportFileOperationFailure extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_file_operation_failure}
  const CoverdeReportFileOperationFailure({
    required this.filePath,
    required this.operation,
    required this.errorMessage,
  });

  /// The file path where the operation failed.
  final String filePath;

  /// The operation that failed (e.g., 'write', 'create').
  final CoverdeReportFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
}

/// {@template coverde_cli.report_file_write_failure}
/// A [ReportCommand] failure that indicates that a file write operation failed.
/// {@endtemplate}
final class CoverdeReportFileWriteFailure
    extends CoverdeReportFileOperationFailure {
  /// {@macro coverde_cli.report_file_write_failure}
  const CoverdeReportFileWriteFailure({
    required super.filePath,
    required super.errorMessage,
  }) : super(
          operation: CoverdeReportFileOperation.write,
        );

  /// Create a [CoverdeReportFileWriteFailure] from a [FileSystemException].
  CoverdeReportFileWriteFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeReportFileOperation.write,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.report_file_create_failure}
/// A [ReportCommand] failure that indicates that a file creation operation
/// failed.
/// {@endtemplate}
final class CoverdeReportFileCreateFailure
    extends CoverdeReportFileOperationFailure {
  /// {@macro coverde_cli.report_file_create_failure}
  const CoverdeReportFileCreateFailure({
    required super.filePath,
    required super.errorMessage,
  }) : super(
          operation: CoverdeReportFileOperation.create,
        );

  /// Create a [CoverdeReportFileCreateFailure] from a [FileSystemException].
  CoverdeReportFileCreateFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeReportFileOperation.create,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}

/// {@template coverde_cli.report_file_read_failure}
/// A [ReportCommand] failure that indicates that a file read operation failed.
/// {@endtemplate}
final class CoverdeReportFileReadFailure
    extends CoverdeReportFileOperationFailure {
  /// {@macro coverde_cli.report_file_read_failure}
  const CoverdeReportFileReadFailure({
    required super.filePath,
    required super.errorMessage,
  }) : super(
          operation: CoverdeReportFileOperation.read,
        );

  /// Create a [CoverdeReportFileReadFailure] from a [FileSystemException].
  CoverdeReportFileReadFailure.fromFileSystemException({
    required super.filePath,
    required FileSystemException exception,
  }) : super(
          operation: CoverdeReportFileOperation.read,
          errorMessage: [
            exception.message,
            if (exception.osError case final osError?) osError.message,
          ].join('\n'),
        );
}
