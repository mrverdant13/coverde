import 'package:coverde/coverde.dart';
import 'package:universal_io/io.dart';

/// {@template coverde_cli.render_failure}
/// The interface for [RenderCommand] failures.
/// {@endtemplate}
sealed class CoverdeRenderFailure extends CoverdeFailure {
  /// {@macro coverde_cli.render_failure}
  const CoverdeRenderFailure();
}

/// {@template coverde_cli.render_invalid_variable_failure}
/// A [RenderCommand] failure that indicates that a `--variable` value is not
/// `name=value`.
/// {@endtemplate}
final class CoverdeRenderInvalidVariableFailure extends CoverdeRenderFailure {
  /// {@macro coverde_cli.render_invalid_variable_failure}
  const CoverdeRenderInvalidVariableFailure({
    required this.rawValue,
    required this.usageMessage,
  });

  /// The `--variable` value that could not be parsed.
  final String rawValue;

  /// The [RenderCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
`--variable` value `$rawValue` must use the form name=value.

$usageMessage
''';
}

/// {@template coverde_cli.render_invalid_trace_file_failure}
/// The interface for [RenderCommand] failures that indicate an invalid trace.
/// {@endtemplate}
sealed class CoverdeRenderInvalidTraceFileFailure extends CoverdeRenderFailure {
  /// {@macro coverde_cli.render_invalid_trace_file_failure}
  const CoverdeRenderInvalidTraceFileFailure({required this.traceFilePath});

  /// The path to the invalid trace file.
  final String traceFilePath;
}

/// {@template coverde_cli.render_trace_file_not_found_failure}
/// A [RenderCommand] failure that indicates that the trace file was not found.
/// {@endtemplate}
final class CoverdeRenderTraceFileNotFoundFailure
    extends CoverdeRenderInvalidTraceFileFailure {
  /// {@macro coverde_cli.render_trace_file_not_found_failure}
  const CoverdeRenderTraceFileNotFoundFailure({required super.traceFilePath});

  @override
  String get readableMessage => 'No trace file found at `$traceFilePath`.';
}

/// {@template coverde_cli.render_empty_trace_file_failure}
/// A [RenderCommand] failure that indicates that the trace file has no records.
/// {@endtemplate}
final class CoverdeRenderEmptyTraceFileFailure
    extends CoverdeRenderInvalidTraceFileFailure {
  /// {@macro coverde_cli.render_empty_trace_file_failure}
  const CoverdeRenderEmptyTraceFileFailure({required super.traceFilePath});

  @override
  String get readableMessage =>
      'No coverage data found in the trace file at `$traceFilePath`.';
}

/// {@template coverde_cli.render_trace_file_read_failure}
/// A [RenderCommand] failure that indicates that a trace file could not be
/// read.
/// {@endtemplate}
final class CoverdeRenderTraceFileReadFailure
    extends CoverdeRenderInvalidTraceFileFailure {
  /// Create a [CoverdeRenderTraceFileReadFailure] from a [FileSystemException].
  CoverdeRenderTraceFileReadFailure.fromFileSystemException({
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

/// {@template coverde_cli.render_config_file_read_failure}
/// A [RenderCommand] failure that indicates that `coverde.yaml` could not be
/// read.
/// {@endtemplate}
final class CoverdeRenderConfigFileReadFailure extends CoverdeRenderFailure {
  /// Creates a [CoverdeRenderConfigFileReadFailure] from a file error.
  CoverdeRenderConfigFileReadFailure.fromFileSystemException({
    required this.configPath,
    required FileSystemException exception,
  }) : errorMessage = [
         exception.message,
         if (exception.osError case final osError?) osError.message,
       ].join('\n');

  /// The configuration file that could not be read.
  final String configPath;

  /// The underlying error message.
  final String errorMessage;

  @override
  String get readableMessage => 'Failed to read `$configPath`.\n$errorMessage';
}
