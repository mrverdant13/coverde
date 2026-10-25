import 'dart:async';
import 'dart:convert';

import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:coverde/src/entities/coverage_trace_format_failure.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:universal_io/io.dart';

/// Parses [trace] into source files.
///
/// A record is kept when it has line or function data. Repeated records for
/// one source file merge. `\` and `/` name the same file, and the stored path
/// keeps the separator from the first record. A trailing record with no
/// `end_of_record` is still parsed.
///
/// Throws [CoverageTraceFormatFailure] when [trace] is not valid line coverage.
List<CoverageFile> parseCoverageTrace(String trace) {
  final files = <CoverageFile>[];
  final indexByPath = <String, int>{};
  for (final record in _records(trace)) {
    final file = _parseRecord(record);
    if (file == null) continue;
    _addParsedFile(files, indexByPath, file);
  }
  return files;
}

/// Parses [file] line by line into source files.
///
/// Records are built as each `end_of_record` arrives. The whole trace is not
/// held as one string. A record is kept when it has line or function data.
/// Repeated records for one source file merge. `\` and `/` name the same
/// file, and the stored path keeps the separator from the first record. A
/// trailing record with no `end_of_record` is still parsed.
///
/// Throws [CoverageTraceFormatFailure] when [file] is not valid line coverage,
/// and [FileSystemException] when [file] cannot be read.
Future<List<CoverageFile>> parseCoverageTraceStreaming(File file) async {
  final files = <CoverageFile>[];
  final indexByPath = <String, int>{};
  final recordLines = <String>[];
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
        if (trimmed == 'end_of_record') {
          if (recordLines.isEmpty) {
            throw const CoverageTraceFormatFailure(
              readableMessage: 'Trace file contains an empty record.',
            );
          }
          _addRecord(
            files: files,
            indexByPath: indexByPath,
            lines: recordLines,
          );
          recordLines.clear();
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
        if (recordLines.isNotEmpty) {
          _addRecord(
            files: files,
            indexByPath: indexByPath,
            lines: recordLines,
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

  return files;
}

void _addRecord({
  required List<CoverageFile> files,
  required Map<String, int> indexByPath,
  required List<String> lines,
}) {
  final file = _parseRecord(lines);
  if (file == null) return;
  _addParsedFile(files, indexByPath, file);
}

void _addParsedFile(
  List<CoverageFile> files,
  Map<String, int> indexByPath,
  CoverageFile file,
) {
  final key = coveragePathSlashForm(file.path);
  final index = indexByPath[key];
  if (index == null) {
    indexByPath[key] = files.length;
    files.add(file);
    return;
  }
  files[index] = _mergeCoverageFiles(files[index], file);
}

CoverageFile _mergeCoverageFiles(CoverageFile current, CoverageFile incoming) {
  return CoverageFile(
    path: current.path,
    entries: [...current.entries, ...incoming.entries],
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
  );
}

List<List<String>> _records(String trace) {
  final records = <List<String>>[];
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
      records.add(List<String>.of(current));
      current.clear();
      continue;
    }
    current.add(line);
  }
  if (current.isNotEmpty) records.add(List<String>.of(current));
  return records;
}

CoverageFile? _parseRecord(List<String> lines) {
  String? sourcePath;
  final entries = <CoverageTraceEntry>[];
  final lineRecords = <CoverageLine>[];
  final functionLines = <String, int>{};
  final functionHits = <String, int>{};
  int? functionsFound;
  int? functionsHit;
  int? linesFound;
  int? linesHit;
  var sawFunctions = false;

  for (final line in lines) {
    entries.add(_traceEntry(line));
    if (line.startsWith('SF:')) {
      if (sourcePath != null) {
        throw const CoverageTraceFormatFailure(
          readableMessage: 'Trace record contains more than one `SF:` line.',
        );
      }
      final rawPath = line.substring('SF:'.length).trim();
      if (rawPath.isEmpty) {
        throw const CoverageTraceFormatFailure(
          readableMessage: 'Trace record has an empty `SF:` path.',
        );
      }
      sourcePath = normalizeCoveragePath(rawPath);
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
  final functions =
      sawFunctions
          ? _functions(
            sourcePath: sourcePath,
            lines: functionLines,
            hits: functionHits,
            found: functionsFound,
            hit: functionsHit,
          )
          : null;

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

  final computedLinesHit = lineRecords.where((line) => line.hasBeenHit).length;
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
  if (lineRecords.isEmpty && functions == null) return null;

  return CoverageFile(
    path: sourcePath,
    entries: [...entries, const CoveragePreservedEntry('end_of_record')],
    lines: lineRecords,
    functions: functions,
  );
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
            '`${function.name}` on lines ${existing.line} '
            'and ${function.line}.',
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

CoverageTraceEntry _traceEntry(String line) {
  if (line.startsWith('SF:')) {
    return CoverageSourceEntry(line.substring('SF:'.length));
  }
  if (line.startsWith('DA:') ||
      line.startsWith('FNDA:') ||
      line.startsWith('FN:') ||
      line.startsWith('FNF:') ||
      line.startsWith('FNH:') ||
      line.startsWith('LF:') ||
      line.startsWith('LH:') ||
      line == 'end_of_record') {
    return CoveragePreservedEntry(line);
  }
  return CoverageUnrecognizedEntry(line);
}
