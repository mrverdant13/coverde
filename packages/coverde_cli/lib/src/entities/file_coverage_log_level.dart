/// The log level for the coverage value for each source file listed in the
/// trace file.
enum FileCoverageLogLevel {
  /// Log nothing.
  none(
    'none',
    'Log nothing.',
  ),

  /// Log the overview of the coverage value for the file.
  overview(
    'overview',
    'Log the overview of the coverage value for the file.',
  ),

  /// Log only the uncovered line numbers.
  lineNumbers(
    'line-numbers',
    'Log only the uncovered line numbers.',
  ),

  /// Log the uncovered line numbers and their content.
  lineContent(
    'line-content',
    'Log the uncovered line numbers and their content.',
  ),
  ;

  const FileCoverageLogLevel(this.identifier, this.help);

  /// The identifier for the log level.
  final String identifier;

  /// The help message for the log level.
  final String help;
}
