/// A set of fake string utils.
extension StringUtils on String {
  /// Returns a new string with the first letter capitalized.
  String get capitalized => '${this[0].toUpperCase()}${substring(1)}';
}
