import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/features/reporting/templates/strict_template_map.dart';
import 'package:coverde/src/utils/coverage.dart';

/// Template maps for one coverage document.
///
/// File maps are shared, so setting `outputPath` is visible from `document`,
/// directory children, and the file render.
final class TemplateContext {
  /// Builds the maps for [document].
  factory TemplateContext({
    required CoverageDocument document,
    required CoverageSourceReader sources,
    CoverageDirectory? tree,
  }) {
    final fileMaps = _createFileMaps(document);
    return TemplateContext._(
      document: document,
      sources: sources,
      fileMaps: fileMaps,
      documentMap: _documentMap(document, fileMaps),
      root: _directoryMap(tree ?? document.tree, fileMaps),
    );
  }

  TemplateContext._({
    required CoverageDocument document,
    required CoverageSourceReader sources,
    required Map<String, StrictTemplateMap> fileMaps,
    required this.documentMap,
    required this.root,
  }) : _document = document,
       _fileMaps = fileMaps,
       _sources = sources;

  final CoverageDocument _document;
  final Map<String, StrictTemplateMap> _fileMaps;
  final CoverageSourceReader _sources;

  /// `document` with source text on every file.
  ///
  /// The shared file maps stay unchanged.
  StrictTemplateMap documentWithSource() {
    return StrictTemplateMap({
      for (final key in documentMap.keys)
        key: key == 'files'
            ? [
                for (final file in _document.files)
                  fileRenderMap(file, includeSource: true),
              ]
            : documentMap[key],
    });
  }

  /// A directory map whose files, at every depth, include source text.
  ///
  /// The shared file maps stay unchanged.
  StrictTemplateMap directoryWithSource(
    CoverageDirectory directory,
    StrictTemplateMap map,
  ) {
    final childMaps = map['directories']! as List<Object?>;
    return StrictTemplateMap({
      for (final key in map.keys)
        key: switch (key) {
          'files' => [
            for (final file in directory.files)
              fileRenderMap(file, includeSource: true),
          ],
          'directories' => [
            for (var index = 0; index < directory.directories.length; index++)
              directoryWithSource(
                directory.directories[index],
                childMaps[index]! as StrictTemplateMap,
              ),
          ],
          _ => map[key],
        },
    });
  }

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
    final source = _sources.readLines(file.path);
    return StrictTemplateMap({
      for (final key in shared.keys)
        key: switch (key) {
          'lines' => _expandedLines(file, source),
          'sourceAvailable' => source != null,
          _ => shared[key],
        },
    });
  }

  static Map<String, StrictTemplateMap> _createFileMaps(
    CoverageDocument document,
  ) {
    return {for (final file in document.files) file.path: _recordFileMap(file)};
  }

  List<StrictTemplateMap> _expandedLines(
    CoverageFile file,
    List<String>? source,
  ) {
    final branches = _branchesOf(file);
    if (source == null) {
      return [
        for (final line in file.lines) _lineMap(line, branches: branches),
      ];
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
          branches: branches,
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
    'functionsHit': document.functionsHit,
    'functionsFound': document.functionsFound,
    'branchRate': document.branchRate,
    'branchesHit': document.branchesHit,
    'branchesFound': document.branchesFound,
    'traceModifiedAt': document.traceModifiedAt?.toIso8601String(),
    'testNames': document.testNames,
    'files': [for (final file in document.files) fileMaps[file.path]],
  });
}

StrictTemplateMap _directoryMap(
  CoverageDirectory directory,
  Map<String, StrictTemplateMap> fileMaps,
) {
  final filesLinesHit = [
    for (final file in directory.files) file.linesHit,
  ].fold<int>(0, (total, value) => total + value);
  final filesLinesFound = [
    for (final file in directory.files) file.linesFound,
  ].fold<int>(0, (total, value) => total + value);
  final filesFunctionsHit = _optionalSum(
    directory.files.map((file) => file.functions?.hit),
  );
  final filesFunctionsFound = _optionalSum(
    directory.files.map((file) => file.functions?.found),
  );
  final filesBranchesHit = _optionalSum(
    directory.files.map((file) => file.branches?.hit),
  );
  final filesBranchesFound = _optionalSum(
    directory.files.map((file) => file.branches?.found),
  );
  final directories = [
    for (final child in directory.directories) _directoryMap(child, fileMaps),
  ];
  final fileDirectories =
      [for (final child in directories) ..._fileDirectoriesOf(child)]
        ..sort((left, right) {
          return (left['path']! as String).compareTo(right['path']! as String);
        });
  return StrictTemplateMap({
    'path': directory.path,
    'name': directory.name,
    'lineRate': directory.lineRate,
    'linesHit': directory.linesHit,
    'linesFound': directory.linesFound,
    'functionRate': directory.functionRate,
    'functionsHit': directory.functionsHit,
    'functionsFound': directory.functionsFound,
    'branchRate': directory.branchRate,
    'branchesHit': directory.branchesHit,
    'branchesFound': directory.branchesFound,
    'filesLineRate': coverageRate(hit: filesLinesHit, found: filesLinesFound),
    'filesLinesHit': filesLinesHit,
    'filesLinesFound': filesLinesFound,
    'filesFunctionRate': optionalCoverageRate(
      hit: filesFunctionsHit,
      found: filesFunctionsFound,
    ),
    'filesFunctionsHit': filesFunctionsHit,
    'filesFunctionsFound': filesFunctionsFound,
    'filesBranchRate': optionalCoverageRate(
      hit: filesBranchesHit,
      found: filesBranchesFound,
    ),
    'filesBranchesHit': filesBranchesHit,
    'filesBranchesFound': filesBranchesFound,
    'outputPath': null,
    'pagePaths': <String>[],
    'files': [for (final file in directory.files) fileMaps[file.path]],
    'directories': directories,
    'fileDirectories': fileDirectories,
  });
}

List<StrictTemplateMap> _fileDirectoriesOf(StrictTemplateMap directory) {
  final files = directory['files']! as List<Object?>;
  final children = directory['directories']! as List<Object?>;
  return [
    if (files.isNotEmpty) directory,
    for (final child in children)
      ..._fileDirectoriesOf(child! as StrictTemplateMap),
  ];
}

int? _optionalSum(Iterable<int?> values) {
  var sawValue = false;
  var total = 0;
  for (final value in values) {
    if (value == null) continue;
    sawValue = true;
    total += value;
  }
  if (!sawValue) return null;
  return total;
}

StrictTemplateMap _recordFileMap(CoverageFile file) {
  return StrictTemplateMap({
    'path': file.path,
    'name': file.name,
    'testName': file.testName,
    'unrecognized': file.unrecognized,
    'sourceAvailable': null,
    'lineRate': file.lineRate,
    'linesHit': file.linesHit,
    'linesFound': file.linesFound,
    'functionRate': file.functionRate,
    'functionsHit': file.functions?.hit,
    'functionsFound': file.functions?.found,
    'functions': _functionMaps(file.functions),
    'branchRate': file.branchRate,
    'branchesHit': file.branches?.hit,
    'branchesFound': file.branches?.found,
    'branches': _branchMaps(file.branches),
    'outputPath': null,
    'pagePaths': <String>[],
    'lines': [
      for (final line in file.lines)
        _lineMap(line, branches: _branchesOf(file)),
    ],
  });
}

List<CoverageBranch> _branchesOf(CoverageFile file) {
  return file.branches?.branches ?? const [];
}

List<StrictTemplateMap>? _functionMaps(CoverageFunctions? functions) {
  if (functions == null) return null;
  return [
    for (final function in functions.functions)
      StrictTemplateMap({
        'name': function.name,
        'line': function.line,
        'hits': function.hits,
      }),
  ];
}

List<StrictTemplateMap>? _branchMaps(CoverageBranches? branches) {
  if (branches == null) return null;
  return [for (final branch in branches.branches) _branchMap(branch)];
}

StrictTemplateMap _branchMap(CoverageBranch branch) {
  return StrictTemplateMap({
    'line': branch.line,
    'block': branch.block,
    'branch': branch.branch,
    'taken': branch.taken,
  });
}

StrictTemplateMap _lineMap(
  CoverageLine? line, {
  int? number,
  String? source,
  List<CoverageBranch> branches = const [],
}) {
  final lineNumber = number ?? line!.number;
  return StrictTemplateMap({
    'number': lineNumber,
    'hits': line?.hits,
    'checksum': line?.checksum,
    'source': source,
    'branches': [
      for (final branch in branches)
        if (branch.line == lineNumber) _branchMap(branch),
    ],
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
