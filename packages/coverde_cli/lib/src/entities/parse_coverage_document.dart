part of 'coverage_document.dart';

/// Parses [trace] as LCOV line coverage.
CoverageDocument _parseCoverageDocument(
  String trace, {
  DateTime? traceModifiedAt,
}) {
  final files = <CoverageFile>[];
  final indexByPath = <String, int>{};
  for (final record in _records(trace)) {
    final file = _parseRecord(record);
    if (file == null) continue;
    _addParsedFile(files, indexByPath, file);
  }
  return CoverageDocument(traceModifiedAt: traceModifiedAt, files: files);
}

Future<CoverageDocument> _parseCoverageDocumentStreaming(
  File file, {
  DateTime? traceModifiedAt,
}) async {
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

  return CoverageDocument(traceModifiedAt: traceModifiedAt, files: files);
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
  final index = indexByPath[file.path];
  if (index == null) {
    indexByPath[file.path] = files.length;
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
  int? linesFound;
  int? linesHit;

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
  if (lineRecords.isEmpty) return null;

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

  return CoverageFile(
    path: sourcePath,
    entries: [...entries, const CoveragePreservedEntry('end_of_record')],
    lines: lineRecords,
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

CoverageTraceEntry _traceEntry(String line) {
  if (line.startsWith('SF:')) {
    return CoverageSourceEntry(line.substring('SF:'.length));
  }
  if (line.startsWith('DA:') ||
      line.startsWith('LF:') ||
      line.startsWith('LH:') ||
      line == 'end_of_record') {
    return CoveragePreservedEntry(line);
  }
  return CoverageUnrecognizedEntry(line);
}
