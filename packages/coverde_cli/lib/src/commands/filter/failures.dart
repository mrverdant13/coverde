import 'package:coverde/coverde.dart';

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
