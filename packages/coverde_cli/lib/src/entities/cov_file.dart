import 'package:collection/collection.dart';
import 'package:coverde/coverde.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// {@template cov_file}
/// # Covered File Data
///
/// A [CovElement] that holds coverage data about a [source] file.
///
/// The data includes the [raw] coverage data about the [source] and the
/// [covLines] with their coverage data.
/// {@endtemplate}
@immutable
class CovFile extends CovElement {
  /// Create a [CovFile] instance.
  ///
  /// {@macro cov_file}
  @visibleForTesting
  CovFile({
    required this.source,
    required this.raw,
    required Iterable<CovLine> covLines,
  }) : _covLines = covLines;

  /// Create a [CovFile] from a [data] trace block string.
  ///
  /// Throws a [CovFileFormatFailure] if the [data] is not a valid trace block.
  factory CovFile.parse(String data) {
    final dataLines = data.split('\n');

    String sourcePath() =>
        dataLines
            .firstWhere(
              (l) => l.startsWith(sourceFileTag),
              orElse:
                  () =>
                      throw const CovFileFormatFailure(
                        readableMessage:
                            'Source file tag not found '
                            'in the trace file block.',
                      ),
            )
            .replaceAll(sourceFileTag, '')
            .trim();

    final sourceFilePath = normalizeSourcePath(sourcePath());

    final covLines = dataLines
        .where((l) => l.startsWith(lineDataTag))
        .map(CovLine.parse);

    return CovFile(source: File(sourceFilePath), raw: data, covLines: covLines);
  }

  /// The raw trace data for the [source].
  final String raw;

  final Iterable<CovLine> _covLines;

  /// The coverage data about the lines of code within the [source].
  late final UnmodifiableListView<CovLine> covLines =
      UnmodifiableListView<CovLine>(_covLines);

  @override
  final File source;

  @override
  late final linesFound = _covLines.length;

  @override
  late final linesHit = _covLines.where((l) => l.hasBeenHit).length;

  /// {@macro cov_line.tag}
  @visibleForTesting
  static const String lineDataTag = CovLine.tag;

  /// The beginning of the line of a trace bloc that contains the [raw] coverage
  /// data about a [source] file.
  static const sourceFileTag = 'SF:';

  /// The `SF:` [raw] path with `/` separators.
  ///
  /// `\` becomes `/`. `.` segments and repeated separators are removed.
  /// A trailing slash is removed. A leading `/` and `..` segments stay.
  static String normalizeSourcePath(String raw) {
    final slashed = raw.trim().replaceAll(r'\', '/');
    final absolute = slashed.startsWith('/');
    final parts = <String>[
      for (final part in slashed.split('/'))
        if (part.isNotEmpty && part != '.') part,
    ];
    if (parts.isEmpty) return absolute ? '/' : '.';
    final joined = parts.join('/');
    return absolute ? '/$joined' : joined;
  }

  /// The ending line of a trace bloc that contains the [raw] coverage data
  /// about a [source] file.
  static const endOfRecordTag = 'end_of_record';

  static const _equality = IterableEquality<CovLine>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CovFile &&
        path.equals(other.source.path, source.path) &&
        _equality.equals(other._covLines, _covLines);
  }

  @override
  int get hashCode =>
      path.canonicalize(source.path).hashCode ^ _equality.hash(_covLines);
}
