/// A set of coverage info line prefixes.
abstract class Prefix {
  Prefix._();

  /// The end of the coverage info for a file.
  static const endOfRecord = 'end_of_record';

  /// A source file path.
  static const sourceFile = 'SF:';
}
