/// A set of coverage info line prefixes.
abstract class Prefix {
  Prefix._();

  /// The end of the coverage info for a file.
  static const endOfRecord = 'end_of_record';

  /// A source file path.
  static const sourceFile = 'SF:';

  /// The quantity of testable lines in the file.
  static const linesFound = 'LF:';

  /// The quantity of tested lines in the file.
  static const linesHit = 'LH:';
}
