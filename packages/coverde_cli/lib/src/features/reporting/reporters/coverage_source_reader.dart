import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template coverde.coverage_source_reader}
/// Reads source text for a coverage file.
/// {@endtemplate}
abstract interface class CoverageSourceReader {
  /// The lines of [path], or null when no file exists at [path].
  ///
  /// Throws [CoverageReportSourceReadFailure] when the file exists and cannot
  /// be read.
  List<String>? readLines(String path);
}

/// {@template coverde.file_coverage_source_reader}
/// A [CoverageSourceReader] that reads from the file system.
/// {@endtemplate}
final class FileCoverageSourceReader implements CoverageSourceReader {
  /// {@macro coverde.file_coverage_source_reader}
  const FileCoverageSourceReader({
    @visibleForTesting File Function(String path) open = File.new,
  }) : _open = open;

  final File Function(String path) _open;

  @override
  List<String>? readLines(String path) {
    final file = _open(path);
    if (!file.existsSync()) return null;
    try {
      return file.readAsLinesSync();
    } on FileSystemException catch (exception) {
      throw CoverageReportSourceReadFailure.fromFileSystemException(
        path: path,
        exception: exception,
      );
    }
  }
}
