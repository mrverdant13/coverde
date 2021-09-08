import 'package:cov_utils/src/cov/prefix.dart';

/// {@template file_coverage}
/// A file coverage data abstraction.
/// {@endtemplate}
class FileCoverage {
  /// {@macro file_coverage}
  const FileCoverage({
    required this.sourceFile,
    required this.linesFound,
    required this.linesHit,
  });

  /// Create a file coverage data abstraction from a file coverage data string.
  factory FileCoverage.parse(String fileCovDataString) {
    final fileCovDataLines = fileCovDataString.split('\n');

    final sourceFile = fileCovDataLines._strValue(Prefix.sourceFile);
    final linesFound = fileCovDataLines._intValue(Prefix.linesFound);
    final linesHit = fileCovDataLines._intValue(Prefix.linesHit);

    return FileCoverage(
      sourceFile: sourceFile,
      linesFound: linesFound,
      linesHit: linesHit,
    );
  }

  /// Source file.
  final String sourceFile;

  /// Testable lines of code found in the [sourceFile].
  final int linesFound;

  /// Tested lines of code in the [sourceFile].
  final int linesHit;

  /// Coverage percentage for the [sourceFile].
  double get coveragePercentage => (linesHit * 100) / linesFound;

  @override
  String toString() => '''
FileCoverage
  ${Prefix.sourceFile} $sourceFile
  ${Prefix.linesFound} $linesFound
  ${Prefix.linesHit} $linesHit''';
}

extension _FileCovDataLines on List<String> {
  String _strValue(String key) =>
      // Find line with the value.
      firstWhere(
        (l) => l.contains(key),
        orElse: () => key,
      )
          // Remove key.
          .replaceAll(key, '')
          // Remove trailing and leading spaces.
          .trim();

  int _intValue(String key) => int.tryParse(_strValue(key)) ?? 0;
}
