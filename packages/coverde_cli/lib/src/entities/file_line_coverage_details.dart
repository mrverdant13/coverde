import 'package:meta/meta.dart';

/// The coverage status of a line of code.
enum FileLineCoverageStatus {
  /// The line is a covered testable line.
  covered('C'),

  /// The line is an uncovered testable line.
  uncovered('U'),

  /// The line is not a testable line.
  neutral(' '),
  ;

  const FileLineCoverageStatus(this.marker);

  /// A single-character marker that represents the coverage status.
  final String marker;
}

/// {@template coverde_cli.file_line_coverage_details}
/// A line of code with its coverage status.
/// {@endtemplate}
@immutable
class FileLineCoverageDetails {
  /// Create a [FileLineCoverageDetails] instance.
  ///
  /// {@macro coverde_cli.file_line_coverage_details}
  const FileLineCoverageDetails({
    required this.lineNumber,
    required this.content,
    required this.status,
  });

  /// The line number.
  final int lineNumber;

  /// The content of the line.
  final String content;

  /// The coverage status of the line.
  final FileLineCoverageStatus status;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileLineCoverageDetails &&
        other.lineNumber == lineNumber &&
        other.content == content &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hashAll([
        FileLineCoverageDetails,
        lineNumber,
        content,
        status,
      ]);
}
