import 'package:coverde/coverde.dart';
import 'package:universal_io/io.dart';

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
  String get readableMessage =>
      '''
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
         invalidInputDescription:
             'Invalid medium threshold: `$rawValue`.\n'
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
         invalidInputDescription:
             'Invalid high threshold: `$rawValue`.\n'
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
  const CoverdeReportInvalidTraceFileFailure({required this.traceFilePath});

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.report_trace_file_not_found_failure}
/// A [ReportCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeReportTraceFileNotFoundFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_trace_file_not_found_failure}
  const CoverdeReportTraceFileNotFoundFailure({required super.traceFilePath});

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.report_empty_trace_file_failure}
/// A [ReportCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeReportEmptyTraceFileFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// {@macro coverde_cli.report_empty_trace_file_failure}
  const CoverdeReportEmptyTraceFileFailure({required super.traceFilePath});

  @override
  String get readableMessage =>
      'No coverage data found in the trace file at `$traceFilePath`.';
}

/// {@template coverde_cli.report_trace_file_read_failure}
/// A [ReportCommand] failure that indicates that a trace file read operation
/// failed.
/// {@endtemplate}
final class CoverdeReportTraceFileReadFailure
    extends CoverdeReportInvalidTraceFileFailure {
  /// Create a [CoverdeReportTraceFileReadFailure] from a [FileSystemException].
  CoverdeReportTraceFileReadFailure.fromFileSystemException({
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

/// An operation on a file.
enum CoverdeReportFileOperation {
  /// The operation to read a file.
  read('read');

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

  /// The operation that failed.
  final CoverdeReportFileOperation operation;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage =>
      'Failed to ${operation.name} file at `$filePath`.\n'
      '$errorMessage';
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
  }) : super(operation: CoverdeReportFileOperation.read);

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

/// {@template coverde_cli.report_missing_report_name_failure}
/// A [ReportCommand] failure that indicates that `report custom` has no name.
/// {@endtemplate}
final class CoverdeReportMissingReportNameFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_missing_report_name_failure}
  const CoverdeReportMissingReportNameFailure({required super.usageMessage})
    : super(invalidInputDescription: 'Missing report name.');
}

/// {@template coverde_cli.report_unexpected_argument_failure}
/// A [ReportCommand] failure that indicates an extra positional argument.
/// {@endtemplate}
final class CoverdeReportUnexpectedArgumentFailure
    extends CoverdeReportInvalidInputFailure {
  /// {@macro coverde_cli.report_unexpected_argument_failure}
  const CoverdeReportUnexpectedArgumentFailure({
    required this.argument,
    required super.usageMessage,
  }) : super(invalidInputDescription: 'Unexpected argument `$argument`.');

  /// The argument that was not accepted.
  final String argument;
}

/// {@template coverde_cli.report_config_file_not_found_failure}
/// A [ReportCommand] failure that indicates that the config path is not a file.
/// {@endtemplate}
final class CoverdeReportConfigFileNotFoundFailure
    extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_config_file_not_found_failure}
  const CoverdeReportConfigFileNotFoundFailure({required this.configPath});

  /// The path that was not a file.
  final String configPath;

  @override
  String get readableMessage => 'Config file at `$configPath` is not a file.';
}

/// {@template coverde_cli.report_config_file_read_failure}
/// A [ReportCommand] failure that indicates that the config file could not be
/// read.
/// {@endtemplate}
final class CoverdeReportConfigFileReadFailure extends CoverdeReportFailure {
  /// Create a [CoverdeReportConfigFileReadFailure] from a file error.
  CoverdeReportConfigFileReadFailure.fromFileSystemException({
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

/// {@template coverde_cli.report_unresolved_coverage_path_failure}
/// A [ReportCommand] failure that indicates a coverage path cannot be read on
/// this operating system.
/// {@endtemplate}
final class CoverdeReportUnresolvedCoveragePathFailure
    extends CoverdeReportFailure {
  /// {@macro coverde_cli.report_unresolved_coverage_path_failure}
  const CoverdeReportUnresolvedCoveragePathFailure({required this.sourcePath});

  /// The coverage path that cannot be resolved.
  final String sourcePath;

  @override
  String get readableMessage =>
      'Coverage path `$sourcePath` cannot be resolved '
      'on this operating system.';
}
