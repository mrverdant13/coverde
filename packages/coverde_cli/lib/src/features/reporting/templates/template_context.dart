import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/templates/strict_template_map.dart';

/// Template maps for one coverage document.
///
/// File maps are shared, so setting `outputPath` is visible from `document`,
/// directory children, and the file render.
final class TemplateContext {
  /// Builds the maps for [document].
  factory TemplateContext({
    required CoverageDocument document,
    required CoverageSourceReader sources,
  }) {
    final fileMaps = _createFileMaps(document);
    return TemplateContext._(
      sources: sources,
      fileMaps: fileMaps,
      documentMap: _documentMap(document, fileMaps),
      root: _directoryMap(document.tree, fileMaps),
    );
  }

  TemplateContext._({
    required CoverageSourceReader sources,
    required Map<String, StrictTemplateMap> fileMaps,
    required this.documentMap,
    required this.root,
  }) : _fileMaps = fileMaps,
       _sources = sources;

  final Map<String, StrictTemplateMap> _fileMaps;
  final CoverageSourceReader _sources;

  /// The `document` value.
  final StrictTemplateMap documentMap;

  /// The tree root.
  final StrictTemplateMap root;

  /// The shared map for [file].
  StrictTemplateMap fileMap(CoverageFile file) => _fileMaps[file.path]!;

  /// A file map whose `lines` include source text when [includeSource] is set.
  StrictTemplateMap fileRenderMap(
    CoverageFile file, {
    required bool includeSource,
  }) {
    final shared = fileMap(file);
    if (!includeSource) return shared;
    return StrictTemplateMap({
      for (final key in shared.keys)
        key: key == 'lines' ? _sourceLines(file) : shared[key],
    });
  }

  static Map<String, StrictTemplateMap> _createFileMaps(
    CoverageDocument document,
  ) {
    return {for (final file in document.files) file.path: _recordFileMap(file)};
  }

  List<StrictTemplateMap> _sourceLines(CoverageFile file) {
    final source = _sources.readLines(file.path);
    if (source == null) {
      return [for (final line in file.lines) _lineMap(line)];
    }
    final byNumber = {for (final line in file.lines) line.number: line};
    final lastNumber = _lastLineNumber(
      sourceLength: source.length,
      lines: file.lines,
    );
    return [
      for (var number = 1; number <= lastNumber; number++)
        _lineMap(
          byNumber[number],
          number: number,
          source: number <= source.length ? source[number - 1] : null,
        ),
    ];
  }
}

StrictTemplateMap _documentMap(
  CoverageDocument document,
  Map<String, StrictTemplateMap> fileMaps,
) {
  return StrictTemplateMap({
    'linesHit': document.linesHit,
    'linesFound': document.linesFound,
    'lineRate': document.lineRate,
    'functionRate': document.functionRate,
    'branchRate': document.branchRate,
    'files': [for (final file in document.files) fileMaps[file.path]],
  });
}

StrictTemplateMap _directoryMap(
  CoverageDirectory directory,
  Map<String, StrictTemplateMap> fileMaps,
) {
  return StrictTemplateMap({
    'path': directory.path,
    'name': directory.name,
    'lineRate': directory.lineRate,
    'linesHit': directory.linesHit,
    'linesFound': directory.linesFound,
    'functionRate': directory.functionRate,
    'branchRate': directory.branchRate,
    'outputPath': null,
    'files': [for (final file in directory.files) fileMaps[file.path]],
    'directories': [
      for (final child in directory.directories) _directoryMap(child, fileMaps),
    ],
  });
}

StrictTemplateMap _recordFileMap(CoverageFile file) {
  return StrictTemplateMap({
    'path': file.path,
    'name': file.name,
    'lineRate': file.lineRate,
    'linesHit': file.linesHit,
    'linesFound': file.linesFound,
    'functionRate': file.functionRate,
    'branchRate': file.branchRate,
    'outputPath': null,
    'lines': [for (final line in file.lines) _lineMap(line)],
  });
}

StrictTemplateMap _lineMap(CoverageLine? line, {int? number, String? source}) {
  return StrictTemplateMap({
    'number': number ?? line!.number,
    'hits': line?.hits,
    'checksum': line?.checksum,
    'source': source,
  });
}

int _lastLineNumber({
  required int sourceLength,
  required List<CoverageLine> lines,
}) {
  var last = sourceLength;
  for (final line in lines) {
    if (line.number > last) last = line.number;
  }
  return last;
}
