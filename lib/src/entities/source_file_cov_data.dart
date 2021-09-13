import 'package:meta/meta.dart';

/// {@template source_file_cov_data}
/// # Source File Coverage Data
///
/// The coverage data of a single source fiel is made up of several
/// human-readable lines of text.
///
/// ## Line Types
///
/// * Source file path:
///
///   ```yaml
///   SF:<path to the source file>
///   ```
/// <br>
///
/// * List of line numbers for each function name found in the source file:
///
///   ```yaml
///   FN:<line number of function start>,<function name>
///   ```
/// <br>
///
/// * List of execution counts for each instrumented function:
///
///   ```yaml
///   FNDA:<execution count>,<function name>
///   ```
/// <br>
///
/// * Number of functions found:
///
///   ```yaml
///   FNF:<number of functions found>
///   ```
/// <br>
///
/// * Number of functions hit:
///
///   ```yaml
///   FNH:<number of function hit>
///   ```
/// <br>
///
/// * List of branch coverage information for each branch:
///
///   ```yaml
///   BRDA:<line number>,<block number>,<branch number>,<taken>
///   ```
///
///   Block number and branch number are internal IDs for the branch. Taken is
///   either '-' if the basic block containing the branch was never executed or
///   a number indicating how often that branch was taken.
///
/// <br>
///
/// * Number of branches found:
///
///   ```yaml
///   BRH:<number of branches found>
///   ```
/// <br>
///
/// * Number of branches hit:
///
///   ```yaml
///   BRH:<number of branches hit>
///   ```
/// <br>
///
/// * List of execution counts for each instrumented line (i.e. a line which
///   resulted in executable code):
///
///   ```yaml
///   DA:<line number>,<execution count>[,<checksum>]
///   ```
///
///   Note that there may be an optional checksum present for each instrumented
///   line.
///
/// <br>
///
/// * Number of lines found:
///
///   ```yaml
///   LF:<number of instrumented lines>
///   ```
/// <br>
///
/// * Number of lines hit:
///
///   ```yaml
///   LH:<number of lines with a non-zero execution count>
///   ```
/// <br>
///
/// * Source file coverage data block ending:
///
///   ```yaml
///   end_of_record
///   ```
///
/// ## References:
///
/// - The [`lcov geninfo`
///   command](http://ltp.sourceforge.net/coverage/lcov/geninfo.1.php) - _FILES_
///   section.
///
/// <br>
/// {@endtemplate}
@immutable
class SourceFileCovData {
  /// Create a source file coverage data instance.
  ///
  /// {@macro source_file_cov_data}
  @visibleForTesting
  const SourceFileCovData({
    required this.raw,
    required this.sourceFile,
    required this.linesFound,
    required this.linesHit,
  });

  /// Create a source file coverage data instance from the content string of a
  /// file coverage data block.
  ///
  /// {@macro source_file_cov_data}
  factory SourceFileCovData.parse(String fileCovDataContent) {
    final covDataLines = fileCovDataContent.split('\n');

    final sourceFile = covDataLines._strValue(sourceFileTag);
    final linesFound = covDataLines._intValue(linesFoundTag);
    final linesHit = RangeError.checkValueInInterval(
      covDataLines._intValue(linesHitTag),
      0,
      linesFound,
      'lines hit',
    );

    return SourceFileCovData(
      raw: fileCovDataContent,
      sourceFile: sourceFile,
      linesFound: linesFound,
      linesHit: linesHit,
    );
  }

  /// Raw string representation of the [sourceFile] coverage data.
  final String raw;

  /// Source file path.
  final String sourceFile;

  /// Number of testable lines in the [sourceFile].
  final int linesFound;

  /// Number of tested lines in the [sourceFile].
  final int linesHit;

  /// Coverage percentage for the [sourceFile].
  ///
  /// From **0.00** to **100.00**.
  double get coveragePercentage => (linesHit * 100) / linesFound;

  /// The tag that identifies the number of testable lines found in the source
  /// file.
  static const linesFoundTag = 'LF:';

  /// The tag that identifies the number of tested lines from the source file.
  static const linesHitTag = 'LH:';

  /// The tag that identifies the tested source file path.
  static const sourceFileTag = 'SF:';

  /// The tag that identifies the end of the coverage data section for a tested
  /// file.
  static const endOfRecordTag = 'end_of_record';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SourceFileCovData &&
        other.sourceFile == sourceFile &&
        other.linesFound == linesFound &&
        other.linesHit == linesHit;
  }

  @override
  int get hashCode =>
      sourceFile.hashCode ^ linesFound.hashCode ^ linesHit.hashCode;
}

extension _FileCovDataLines on List<String> {
  /// Find a string value from a list of coverage data lines.
  String _strValue(String key) =>
      // Find line with the value.
      firstWhere(
        (l) => l.startsWith(key),
        orElse: () => throw StateError(
          '<$key> not found in the source file coverage data.',
        ),
      )
          // Remove key.
          .replaceAll(key, '')
          // Remove trailing and leading spaces.
          .trim();

  /// Find an integer value from a list of coverage data lines.
  int _intValue(String key) => ArgumentError.checkNotNull<int>(
        int.tryParse(_strValue(key)),
        key,
      );
}
