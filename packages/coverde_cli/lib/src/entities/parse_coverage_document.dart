part of 'coverage_document.dart';

/// Parses [trace] as LCOV.
///
/// Throws [CoverageTraceFormatFailure] when a record is incomplete or a
/// summary line disagrees with the records it summarizes.
CoverageDocument _parseCoverageDocument(
  String trace, {
  DateTime? traceModifiedAt,
}) {
  final files = <CoverageFile>[];
  for (final record in _records(trace)) {
    final file = _parseRecord(record.lines, raw: record.raw);
    if (file == null) continue;
    _addParsedFile(files, file);
  }
  return CoverageDocument(traceModifiedAt: traceModifiedAt, files: files);
}

Future<CoverageDocument> _parseCoverageDocumentStreaming(
  File file, {
  DateTime? traceModifiedAt,
}) async {
  final files = <CoverageFile>[];
  final recordLines = <String>[];
  final rawLines = <String>[];
  final lines = file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final completer = Completer<void>();

  late final StreamSubscription<String> subscription;
  subscription = lines.listen(
    (line) {
      try {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;
        rawLines.add(line);
        if (trimmed == 'end_of_record') {
          if (recordLines.isEmpty) {
            throw const CoverageTraceFormatFailure(
              readableMessage: 'Trace file contains an empty record.',
            );
          }
          _addRecord(
            files: files,
            lines: recordLines,
            raw: rawLines.join('\n'),
          );
          recordLines.clear();
          rawLines.clear();
          return;
        }
        recordLines.add(trimmed);
      } on Object catch (error, stackTrace) {
        unawaited(subscription.cancel());
        if (completer.isCompleted) return;
        completer.completeError(error, stackTrace);
      }
    },
    onDone: () {
      try {
        if (recordLines.isNotEmpty || rawLines.isNotEmpty) {
          throw const CoverageTraceFormatFailure(
            readableMessage: 'Trace file ended before `end_of_record`.',
          );
        }
        if (completer.isCompleted) return;
        completer.complete();
      } on Object catch (error, stackTrace) {
        if (completer.isCompleted) return;
        completer.completeError(error, stackTrace);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
    },
    cancelOnError: true,
  );
  try {
    await completer.future;
  } on Object {
    rethrow;
  } finally {
    await subscription.cancel();
  }

  return CoverageDocument(traceModifiedAt: traceModifiedAt, files: files);
}

void _addRecord({
  required List<CoverageFile> files,
  required List<String> lines,
  required String raw,
}) {
  final file = _parseRecord(lines, raw: raw);
  if (file == null) return;
  _addParsedFile(files, file);
}

void _addParsedFile(List<CoverageFile> files, CoverageFile file) {
  final index = files.indexWhere((existing) => existing.path == file.path);
  if (index == -1) {
    files.add(file);
    return;
  }
  files[index] = _mergeCoverageFiles(files[index], file);
}

CoverageFile _mergeCoverageFiles(CoverageFile current, CoverageFile incoming) {
  return CoverageFile(
    path: current.path,
    raw: '${current.raw}\n${incoming.raw}',
    lines: _mergeLines(
      sourcePath: current.path,
      current: current.lines,
      incoming: incoming.lines,
    ),
    functions: _mergeFunctions(
      sourcePath: current.path,
      current: current.functions,
      incoming: incoming.functions,
    ),
    branches: _mergeBranches(
      current: current.branches,
      incoming: incoming.branches,
    ),
  );
}

final class _TraceRecord {
  const _TraceRecord({required this.lines, required this.raw});

  final List<String> lines;
  final String raw;
}

List<_TraceRecord> _records(String trace) {
  final records = <_TraceRecord>[];
  final current = <String>[];
  for (final rawLine in trace.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line == 'end_of_record') {
      if (current.isEmpty) {
        throw const CoverageTraceFormatFailure(
          readableMessage: 'Trace file contains an empty record.',
        );
      }
      records.add(
        _TraceRecord(
          lines: List<String>.of(current),
          raw: [...current, 'end_of_record'].join('\n'),
        ),
      );
      current.clear();
      continue;
    }
    current.add(line);
  }
  if (current.isNotEmpty) {
    throw const CoverageTraceFormatFailure(
      readableMessage: 'Trace file ended before `end_of_record`.',
    );
  }
  return records;
}

CoverageFile? _parseRecord(List<String> lines, {required String raw}) {
  String? sourcePath;
  final lineRecords = <CoverageLine>[];
  final functionLines = <String, int>{};
  final functionHits = <String, int>{};
  final branchRecords = <CoverageBranch>[];
  int? functionsFound;
  int? functionsHit;
  int? branchesFound;
  int? branchesHit;
  int? linesFound;
  int? linesHit;
  var sawFunctions = false;
  var sawBranches = false;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      if (sourcePath != null) {
        throw const CoverageTraceFormatFailure(
          readableMessage: 'Trace record contains more than one `SF:` line.',
        );
      }
      sourcePath = _normalizePath(line.substring('SF:'.length));
      if (sourcePath.isEmpty) {
        throw const CoverageTraceFormatFailure(
          readableMessage: 'Trace record has an empty `SF:` path.',
        );
      }
    } else if (line.startsWith('DA:')) {
      lineRecords.add(_parseLine(line.substring('DA:'.length)));
    } else if (line.startsWith('FNDA:')) {
      sawFunctions = true;
      final (hits, name) = _splitOnce(
        line.substring('FNDA:'.length),
        label: 'FNDA',
      );
      if (functionHits.containsKey(name)) {
        throw CoverageTraceFormatFailure(
          readableMessage: 'Trace record repeats function `$name`.',
        );
      }
      functionHits[name] = _parseCount(hits, label: 'FNDA');
    } else if (line.startsWith('FN:')) {
      sawFunctions = true;
      final (rawLine, name) = _parseFunctionRecord(
        line.substring('FN:'.length),
      );
      if (functionLines.containsKey(name)) {
        throw CoverageTraceFormatFailure(
          readableMessage: 'Trace record repeats function `$name`.',
        );
      }
      functionLines[name] = _parsePositive(rawLine, label: 'FN');
    } else if (line.startsWith('FNF:')) {
      sawFunctions = true;
      functionsFound = _parseSummaryOnce(
        current: functionsFound,
        raw: line.substring('FNF:'.length),
        label: 'FNF',
      );
    } else if (line.startsWith('FNH:')) {
      sawFunctions = true;
      functionsHit = _parseSummaryOnce(
        current: functionsHit,
        raw: line.substring('FNH:'.length),
        label: 'FNH',
      );
    } else if (line.startsWith('BRDA:')) {
      sawBranches = true;
      branchRecords.add(_parseBranch(line.substring('BRDA:'.length)));
    } else if (line.startsWith('BRF:')) {
      sawBranches = true;
      branchesFound = _parseSummaryOnce(
        current: branchesFound,
        raw: line.substring('BRF:'.length),
        label: 'BRF',
      );
    } else if (line.startsWith('BRH:')) {
      sawBranches = true;
      branchesHit = _parseSummaryOnce(
        current: branchesHit,
        raw: line.substring('BRH:'.length),
        label: 'BRH',
      );
    } else if (line.startsWith('LF:')) {
      linesFound = _parseSummaryOnce(
        current: linesFound,
        raw: line.substring('LF:'.length),
        label: 'LF',
      );
    } else if (line.startsWith('LH:')) {
      linesHit = _parseSummaryOnce(
        current: linesHit,
        raw: line.substring('LH:'.length),
        label: 'LH',
      );
    }
  }

  if (sourcePath == null) {
    throw const CoverageTraceFormatFailure(
      readableMessage: 'Trace record is missing an `SF:` line.',
    );
  }

  final seenLineNumbers = <int>{};
  for (final record in lineRecords) {
    if (!seenLineNumbers.add(record.number)) {
      throw CoverageTraceFormatFailure(
        readableMessage:
            'Trace record for `$sourcePath` repeats line ${record.number}.',
      );
    }
  }
  lineRecords.sort((left, right) => left.number.compareTo(right.number));

  final computedLinesHit = lineRecords.where((line) => line.hits > 0).length;
  if (linesFound != null && linesFound != lineRecords.length) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `LF:$linesFound`, '
          'which does not match ${lineRecords.length} instrumented lines.',
    );
  }
  if (linesHit != null && linesHit != computedLinesHit) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `LH:$linesHit`, '
          'which does not match $computedLinesHit covered lines.',
    );
  }

  final file = CoverageFile(
    path: sourcePath,
    raw: raw,
    lines: lineRecords,
    functions:
        sawFunctions
            ? _functions(
              sourcePath: sourcePath,
              lines: functionLines,
              hits: functionHits,
              found: functionsFound,
              hit: functionsHit,
            )
            : null,
    branches:
        sawBranches
            ? _branches(
              sourcePath: sourcePath,
              branches: branchRecords,
              found: branchesFound,
              hit: branchesHit,
            )
            : null,
  );
  if (file.lines.isEmpty && file.functions == null && file.branches == null) {
    return null;
  }
  return file;
}

CoverageFunctions _functions({
  required String sourcePath,
  required Map<String, int> lines,
  required Map<String, int> hits,
  required int? found,
  required int? hit,
}) {
  final names = {...lines.keys, ...hits.keys}.toList()..sort();
  final functions = [
    for (final name in names)
      CoverageFunction(name: name, line: lines[name], hits: hits[name] ?? 0),
  ];
  final computedFound = functions.length;
  final computedHit = functions.where((function) => function.hits > 0).length;
  if (found != null && found != computedFound) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `FNF:$found`, '
          'which does not match $computedFound functions.',
    );
  }
  if (hit != null && hit != computedHit) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `FNH:$hit`, '
          'which does not match $computedHit hit functions.',
    );
  }
  return CoverageFunctions(
    hit: computedHit,
    found: computedFound,
    functions: functions,
  );
}

CoverageBranches _branches({
  required String sourcePath,
  required List<CoverageBranch> branches,
  required int? found,
  required int? hit,
}) {
  final computedHit =
      branches.where((branch) => (branch.taken ?? 0) > 0).length;
  if (found != null && found != branches.length) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `BRF:$found`, '
          'which does not match ${branches.length} branches.',
    );
  }
  if (hit != null && hit != computedHit) {
    throw CoverageTraceFormatFailure(
      readableMessage:
          'Trace record for `$sourcePath` has `BRH:$hit`, '
          'which does not match $computedHit taken branches.',
    );
  }
  return CoverageBranches(
    hit: computedHit,
    found: branches.length,
    branches: branches,
  );
}

CoverageLine _parseLine(String raw) {
  final parts = raw.split(',');
  if (parts.length < 2 || parts.length > 3) {
    throw CoverageTraceFormatFailure(
      readableMessage: 'Invalid `DA:` record `$raw`.',
    );
  }
  return CoverageLine(
    number: _parsePositive(parts[0], label: 'DA'),
    hits: _parseCount(parts[1], label: 'DA'),
    checksum: parts.length == 3 ? _parseInt(parts[2], label: 'DA') : null,
  );
}

CoverageBranch _parseBranch(String raw) {
  final parts = raw.split(',');
  if (parts.length != 4) {
    throw CoverageTraceFormatFailure(
      readableMessage: 'Invalid `BRDA:` record `$raw`.',
    );
  }
  final taken = parts[3] == '-' ? null : _parseCount(parts[3], label: 'BRDA');
  return CoverageBranch(
    line: _parsePositive(parts[0], label: 'BRDA'),
    block: _parseCount(parts[1], label: 'BRDA'),
    branch: _parseCount(parts[2], label: 'BRDA'),
    taken: taken,
  );
}

(String, String) _parseFunctionRecord(String raw) {
  final (start, rest) = _splitOnce(raw, label: 'FN');
  final comma = rest.indexOf(',');
  if (comma <= 0) return (start, rest);
  final endLine = int.tryParse(rest.substring(0, comma).trim());
  if (endLine == null || endLine < 1) return (start, rest);
  final name = rest.substring(comma + 1);
  if (name.isEmpty) {
    throw CoverageTraceFormatFailure(
      readableMessage: 'Invalid `FN:` record `$raw`.',
    );
  }
  return (start, name);
}

(String, String) _splitOnce(String raw, {required String label}) {
  final comma = raw.indexOf(',');
  if (comma <= 0 || comma == raw.length - 1) {
    throw CoverageTraceFormatFailure(
      readableMessage: 'Invalid `$label:` record `$raw`.',
    );
  }
  return (raw.substring(0, comma), raw.substring(comma + 1));
}

int _parseSummaryOnce({
  required int? current,
  required String raw,
  required String label,
}) {
  if (current != null) {
    throw CoverageTraceFormatFailure(
      readableMessage: 'Trace record repeats `$label:`.',
    );
  }
  return _parseCount(raw, label: label);
}

int _parsePositive(String raw, {required String label}) {
  final value = _parseInt(raw, label: label);
  if (value < 1) {
    throw CoverageTraceFormatFailure(
      readableMessage: '`$label:` value `$raw` must be a positive line number.',
    );
  }
  return value;
}

int _parseCount(String raw, {required String label}) {
  final value = _parseInt(raw, label: label);
  if (value < 0) {
    throw CoverageTraceFormatFailure(
      readableMessage: '`$label:` value `$raw` must not be negative.',
    );
  }
  return value;
}

int _parseInt(String raw, {required String label}) {
  final value = int.tryParse(raw.trim());
  if (value == null) {
    throw CoverageTraceFormatFailure(
      readableMessage: '`$label:` value `$raw` is not an integer.',
    );
  }
  return value;
}

String _normalizePath(String raw) {
  final normalized = raw.trim().replaceAll(r'\', '/');
  if (normalized.length <= 1) return normalized;
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

List<CoverageLine> _mergeLines({
  required String sourcePath,
  required List<CoverageLine> current,
  required List<CoverageLine> incoming,
}) {
  final byNumber = <int, CoverageLine>{
    for (final line in current) line.number: line,
  };
  for (final line in incoming) {
    final existing = byNumber[line.number];
    if (existing == null) {
      byNumber[line.number] = line;
      continue;
    }
    byNumber[line.number] = CoverageLine(
      number: line.number,
      hits: existing.hits + line.hits,
      checksum: _mergedChecksum(
        sourcePath: sourcePath,
        lineNumber: line.number,
        current: existing.checksum,
        incoming: line.checksum,
      ),
    );
  }
  final lines =
      byNumber.values.toList()
        ..sort((left, right) => left.number.compareTo(right.number));
  return lines;
}

int? _mergedChecksum({
  required String sourcePath,
  required int lineNumber,
  required int? current,
  required int? incoming,
}) {
  if (current == null) return incoming;
  if (incoming == null || current == incoming) return current;
  throw CoverageTraceFormatFailure(
    readableMessage:
        'Trace record for `$sourcePath` repeats line $lineNumber '
        'with checksums `$current` and `$incoming`.',
  );
}

CoverageFunctions? _mergeFunctions({
  required String sourcePath,
  required CoverageFunctions? current,
  required CoverageFunctions? incoming,
}) {
  if (current == null) return incoming;
  if (incoming == null) return current;
  final byName = <String, CoverageFunction>{
    for (final function in current.functions) function.name: function,
  };
  for (final function in incoming.functions) {
    final existing = byName[function.name];
    if (existing == null) {
      byName[function.name] = function;
      continue;
    }
    if (existing.line != null &&
        function.line != null &&
        existing.line != function.line) {
      throw CoverageTraceFormatFailure(
        readableMessage:
            'Trace record for `$sourcePath` repeats function '
            '`${function.name}` on lines ${existing.line} and ${function.line}.',
      );
    }
    byName[function.name] = CoverageFunction(
      name: function.name,
      line: existing.line ?? function.line,
      hits: existing.hits + function.hits,
    );
  }
  final functions =
      byName.values.toList()
        ..sort((left, right) => left.name.compareTo(right.name));
  return CoverageFunctions(
    hit: functions.where((function) => function.hits > 0).length,
    found: functions.length,
    functions: functions,
  );
}

CoverageBranches? _mergeBranches({
  required CoverageBranches? current,
  required CoverageBranches? incoming,
}) {
  if (current == null) return incoming;
  if (incoming == null) return current;
  final byKey = <(int, int, int), CoverageBranch>{
    for (final branch in current.branches)
      (branch.line, branch.block, branch.branch): branch,
  };
  for (final branch in incoming.branches) {
    final key = (branch.line, branch.block, branch.branch);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = branch;
      continue;
    }
    final taken = switch ((existing.taken, branch.taken)) {
      (null, final int? incomingTaken) => incomingTaken,
      (final int currentTaken, null) => currentTaken,
      (final int currentTaken, final int incomingTaken) =>
        currentTaken + incomingTaken,
    };
    byKey[key] = CoverageBranch(
      line: branch.line,
      block: branch.block,
      branch: branch.branch,
      taken: taken,
    );
  }
  final branches = byKey.values.toList();
  return CoverageBranches(
    hit: branches.where((branch) => (branch.taken ?? 0) > 0).length,
    found: branches.length,
    branches: branches,
  );
}
