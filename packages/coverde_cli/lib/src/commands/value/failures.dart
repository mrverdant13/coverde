import 'package:coverde/coverde.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.value_failure}
/// The interface for [ValueCommand] failures.
/// {@endtemplate}
sealed class CoverdeValueFailure extends CoverdeFailure {
  /// {@macro coverde_cli.value_failure}
  const CoverdeValueFailure();
}

/// {@template coverde_cli.value_invalid_trace_file_failure}
/// The interface for [ValueCommand] failures that indicates that an invalid
/// trace file was provided.
/// {@endtemplate}
sealed class CoverdeValueInvalidTraceFileFailure extends CoverdeValueFailure {
  /// {@macro coverde_cli.value_invalid_trace_file_failure}
  const CoverdeValueInvalidTraceFileFailure({
    required this.traceFilePath,
  });

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.value_trace_file_not_found_failure}
/// A [ValueCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeValueTraceFileNotFoundFailure
    extends CoverdeValueInvalidTraceFileFailure {
  /// {@macro coverde_cli.value_trace_file_not_found_failure}
  const CoverdeValueTraceFileNotFoundFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.value_empty_trace_file_failure}
/// A [ValueCommand] failure that indicates that the trace file is empty.
/// {@endtemplate}
final class CoverdeValueEmptyTraceFileFailure
    extends CoverdeValueInvalidTraceFileFailure {
  /// {@macro coverde_cli.value_empty_trace_file_failure}
  const CoverdeValueEmptyTraceFileFailure({
    required super.traceFilePath,
  });

  @override
  String get readableMessage =>
      'No coverage data found in the trace file at `$traceFilePath`.';
}

/// {@template coverde_cli.value_file_read_failure}
/// A [ValueCommand] failure that indicates that a file read operation failed.
/// {@endtemplate}
final class CoverdeValueFileReadFailure extends CoverdeValueFailure {
  /// Create a [CoverdeValueFileReadFailure] from a [FileSystemException].
  CoverdeValueFileReadFailure.fromFileSystemException({
    required this.filePath,
    required FileSystemException exception,
  }) : errorMessage = [
          exception.message,
          if (exception.osError case final osError?) osError.message,
        ].join('\n');

  /// The file path where the read operation failed.
  final String filePath;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage => 'Failed to read file at `$filePath`.\n'
      '$errorMessage';
}
