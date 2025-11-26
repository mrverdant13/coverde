import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

Iterable<MapEntry<int, int>> buildCovLinesEntries(int linesCount) {
  return Iterable.generate(
    linesCount,
    (idx) => MapEntry(idx + 1, idx),
  );
}

String buildRawCovFileString(int linesCount) {
  final buf = StringBuffer()
    ..writeln('SF:${path.joinAll([
          'path',
          'to',
          'source.${linesCount + 1}.file',
        ])}');
  final covLinesEntries = buildCovLinesEntries(linesCount + 1);
  for (final covLineEntry in covLinesEntries) {
    buf.writeln('DA:${covLineEntry.key},${covLineEntry.value}');
  }
  buf.writeln('end_of_record');
  return buf.toString();
}

TraceFile buildTraceFile(int covFilesCount) {
  final covFiles = Iterable.generate(covFilesCount, buildRawCovFileString)
      .map(CovFile.parse);
  final traceFile = TraceFile(
    sourceFilesCovData: covFiles,
  );
  return traceFile;
}

void main() {
  group('$TraceFile', () {
    group('isEmpty', () {
      test('| returns `true` when no source files coverage data is found', () {
        final traceFile = buildTraceFile(0);
        expect(traceFile.isEmpty, isTrue);
      });
    });

    const covFilesCount = 10;

    final covFiles = Iterable.generate(covFilesCount, buildRawCovFileString)
        .map(CovFile.parse);

    final traceFile = TraceFile(
      sourceFilesCovData: covFiles,
    );
    final traceFileString = Iterable.generate(
      covFilesCount,
      buildRawCovFileString,
    ).join('\n');

    test(
      '| supports value comparison',
      () {
        final sameTraceFile = TraceFile(
          sourceFilesCovData: covFiles,
        );

        final valueComparisonResult = traceFile == sameTraceFile;
        final hashComparisonResult =
            traceFile.hashCode == sameTraceFile.hashCode;

        expect(valueComparisonResult, isTrue);
        expect(hashComparisonResult, isTrue);
      },
    );

    test(
      '| parses valid string representation',
      () async {
        final result = TraceFile.parse(
          traceFileString,
        );

        expect(result, traceFile);
      },
    );

    test(
      'sourceFilesCovData '
      '| returns source files coverage data',
      () async {
        final result = traceFile.sourceFilesCovData;

        expect(result, isA<UnmodifiableListView<CovFile>>());
        expect(result.length, covFiles.length);
        expect(
          result,
          predicate<UnmodifiableListView<CovFile>>(
            (r) => r.foldIndexed(
              true,
              (idx, containSameElements, element) =>
                  containSameElements && element == covFiles.elementAt(idx),
            ),
          ),
        );
      },
    );

    test(
      'linesHit '
      '| returns total number of hit lines',
      () async {
        const expectedLinesHit = (covFilesCount * (covFilesCount - 1)) / 2;

        final result = traceFile.linesHit;

        expect(result, expectedLinesHit);
      },
    );

    test(
      'linesFound '
      '| returns total number of found lines',
      () async {
        const expectedLinesFound = (covFilesCount * (covFilesCount + 1)) / 2;

        final result = traceFile.linesFound;

        expect(result, expectedLinesFound);
      },
    );

    group('parseStreaming', () {
      test(
        '| parses valid file and produces same result as parse',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final tempFile = File(path.join(tempDir.path, 'trace.info'))
            ..writeAsStringSync(traceFileString);

          final result = await TraceFile.parseStreaming(tempFile);

          expect(result, traceFile);
        },
      );

      test(
        '| handles empty file',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final tempFile = File(path.join(tempDir.path, 'empty.info'))
            ..writeAsStringSync('');

          final result = await TraceFile.parseStreaming(tempFile);

          expect(result.isEmpty, isTrue);
        },
      );

      test(
        '| handles file with only whitespace',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final tempFile = File(path.join(tempDir.path, 'whitespace.info'))
            ..writeAsStringSync('   \n\n  \n  ');

          final result = await TraceFile.parseStreaming(tempFile);

          expect(result.isEmpty, isTrue);
        },
      );

      test(
        '| handles file with multiple blocks',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final multiBlockContent = '''
${buildRawCovFileString(5)}
${buildRawCovFileString(10)}
${buildRawCovFileString(3)}
''';
          final tempFile = File(path.join(tempDir.path, 'multi.info'))
            ..writeAsStringSync(multiBlockContent);

          final result = await TraceFile.parseStreaming(tempFile);
          final expected = TraceFile.parse(multiBlockContent);

          expect(result, expected);
        },
      );

      test(
        '| handles large file efficiently',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          // Create a file with many blocks (simulating large trace file)
          final largeContent =
              Iterable.generate(100, buildRawCovFileString).join('\n');
          final tempFile = File(path.join(tempDir.path, 'large.info'))
            ..writeAsStringSync(largeContent);

          final result = await TraceFile.parseStreaming(tempFile);
          final expected = TraceFile.parse(largeContent);

          expect(result.sourceFilesCovData.length, 100);
          expect(result, expected);
        },
      );

      test(
        '| handles file with no end_of_record at end gracefully',
        () async {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final contentWithoutEnd = '''
${buildRawCovFileString(5)}
SF:incomplete/file.dart
DA:1,1
''';
          final tempFile = File(path.join(tempDir.path, 'incomplete.info'))
            ..writeAsStringSync(contentWithoutEnd);

          final result = await TraceFile.parseStreaming(tempFile);

          // Should handle incomplete block at end
          expect(result.sourceFilesCovData.length, 2);
        },
      );
    });
  });
}
