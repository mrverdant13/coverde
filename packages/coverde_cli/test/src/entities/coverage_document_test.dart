import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:coverde/src/entities/coverage_trace_format_failure.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$CoverageDocument', () {
    test('parses line records and keeps the source separator', () {
      const trace = r'''
SF:lib\src\..\a.dart
DA:2,0
DA:1,1,9
FN:10,main
BRDA:1,0,0,1
TN:suite
end_of_record
''';

      final file = CoverageDocument.parse(trace).files.single;

      expect(file.path, r'lib\a.dart');
      expect(file.name, 'a.dart');
      expect(file.linesFound, 2);
      expect(file.linesHit, 1);
      expect(file.lineRate, 50);
      expect(file.lines, const [
        CoverageLine(number: 1, hits: 1, checksum: 9),
        CoverageLine(number: 2, hits: 0),
      ]);
      expect(
        file.renderTrace(),
        'SF:lib\\a.dart\n'
        'DA:2,0\n'
        'DA:1,1,9\n'
        'FN:10,main\n'
        'BRDA:1,0,0,1\n'
        'TN:suite\n'
        'end_of_record',
      );
    });

    test('keeps the first separator when a path mixes both', () {
      const trace = r'''
SF:C:\src/foo\..\a.dart
DA:1,1
end_of_record
''';

      final file = CoverageDocument.parse(trace).files.single;

      expect(file.path, r'C:\src\a.dart');
      expect(file.renderTrace(), startsWith(r'SF:C:\src\a.dart'));
      expect(
        file.renderTrace(sourcePath: r'.\b.dart'),
        'SF:b.dart\nDA:1,1\nend_of_record',
      );
    });

    test('drops a record that has no DA lines', () {
      const trace = '''
SF:lib/empty.dart
TN:ignored
end_of_record
SF:lib/fn.dart
FN:4,only
end_of_record
SF:lib/kept.dart
DA:1,1
end_of_record
''';

      final document = CoverageDocument.parse(trace);

      expect(document.files.map((file) => file.path), ['lib/kept.dart']);
      expect(document.linesFound, 1);
      expect(document.lineRate, 100);
    });

    test('merges records that share a normalized path', () {
      const trace = r'''
SF:lib\a.dart
DA:1,1
TN:first
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
SF:lib\.\a.dart
DA:1,2,4
DA:3,0
TN:second
end_of_record
''';

      final document = CoverageDocument.parse(trace);

      expect(document.files.map((file) => file.path), [
        r'lib\a.dart',
        'lib/b.dart',
      ]);
      final merged = document.files.first;
      expect(merged.lines, const [
        CoverageLine(number: 1, hits: 3, checksum: 4),
        CoverageLine(number: 3, hits: 0),
      ]);
      expect(merged.linesFound, 2);
      expect(merged.linesHit, 1);
      expect(document.linesFound, 3);
      expect(document.linesHit, 1);
      expect(
        merged.renderTrace(),
        'SF:lib\\a.dart\n'
        'DA:1,1\n'
        'TN:first\n'
        'end_of_record\n'
        'SF:lib\\a.dart\n'
        'DA:1,2,4\n'
        'DA:3,0\n'
        'TN:second\n'
        'end_of_record',
      );
    });

    test('merges records that differ only by separator', () {
      const trace = r'''
SF:lib/a.dart
DA:1,1
TN:slash
end_of_record
SF:lib\a.dart
DA:1,0
DA:2,1
TN:backslash
end_of_record
SF:C:\proj\a.dart
DA:4,1
end_of_record
SF:C:/proj/a.dart
DA:4,2,7
end_of_record
SF://server/share/a.dart
DA:1,1
end_of_record
SF:\\server\share\a.dart
DA:1,0
end_of_record
''';

      final document = CoverageDocument.parse(trace);

      expect(document.files.map((file) => file.path), [
        'lib/a.dart',
        r'C:\proj\a.dart',
        '//server/share/a.dart',
      ]);
      final relative = document.files[0];
      expect(relative.lines, const [
        CoverageLine(number: 1, hits: 1),
        CoverageLine(number: 2, hits: 1),
      ]);
      expect(
        relative.renderTrace(),
        'SF:lib/a.dart\n'
        'DA:1,1\n'
        'TN:slash\n'
        'end_of_record\n'
        'SF:lib/a.dart\n'
        'DA:1,0\n'
        'DA:2,1\n'
        'TN:backslash\n'
        'end_of_record',
      );
      expect(document.files[1].lines, const [
        CoverageLine(number: 4, hits: 3, checksum: 7),
      ]);
      expect(document.files[2].linesHit, 1);
      expect(document.linesFound, 4);
      expect(document.linesHit, 4);
      expect(document.tree.directories.first.files, hasLength(1));
    });

    test('keeps paths apart when the difference is not the separator', () {
      const trace = '''
SF:src/a.dart
DA:1,1
end_of_record
SF:/src/a.dart
DA:1,0
end_of_record
SF:C:/src/a.dart
DA:1,1
end_of_record
SF:C:src/a.dart
DA:1,0
end_of_record
SF:Lib/a.dart
DA:1,1
end_of_record
SF:lib/a.dart
DA:1,0
end_of_record
SF://server/share/a.dart
DA:1,1
end_of_record
SF://other/share/a.dart
DA:1,0
end_of_record
''';

      expect(CoverageDocument.parse(trace).files.map((file) => file.path), [
        'src/a.dart',
        '/src/a.dart',
        'C:/src/a.dart',
        'C:src/a.dart',
        'Lib/a.dart',
        'lib/a.dart',
        '//server/share/a.dart',
        '//other/share/a.dart',
      ]);
    });

    test('rejects a summary that disagrees with the DA lines', () {
      const found = '''
SF:lib/a.dart
DA:1,1
LF:2
end_of_record
''';
      const hit = '''
SF:lib/a.dart
DA:1,0
LH:1
end_of_record
''';

      expect(
        () => CoverageDocument.parse(found),
        throwsA(
          isA<CoverageTraceFormatFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('LF:2'),
          ),
        ),
      );
      expect(
        () => CoverageDocument.parse(hit),
        throwsA(
          isA<CoverageTraceFormatFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('LH:1'),
          ),
        ),
      );
    });

    test('parses a record that omits LF and LH', () {
      const trace = '''
SF:lib/a.dart
DA:1,1
end_of_record
''';

      expect(CoverageDocument.parse(trace).files.single.linesFound, 1);
    });

    test('rejects malformed records', () {
      void expectFailure(String trace, String message) {
        expect(
          () => CoverageDocument.parse(trace),
          throwsA(
            isA<CoverageTraceFormatFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains(message),
            ),
          ),
        );
      }

      expectFailure('end_of_record\n', 'empty record');
      expectFailure('DA:1,1\nend_of_record\n', 'missing an `SF:`');
      expectFailure('SF:\nDA:1,1\nend_of_record\n', 'empty `SF:`');
      expectFailure(
        'SF:a.dart\nSF:b.dart\nDA:1,1\nend_of_record\n',
        'more than one `SF:`',
      );
      expectFailure(
        'SF:a.dart\nDA:1,1\nDA:1,2\nend_of_record\n',
        'repeats line 1',
      );
      expectFailure('SF:a.dart\nDA:1\nend_of_record\n', 'Invalid `DA:`');
      expectFailure('SF:a.dart\nDA:0,1\nend_of_record\n', 'positive line');
      expectFailure('SF:a.dart\nDA:1,-1\nend_of_record\n', 'not be negative');
      expectFailure('SF:a.dart\nDA:1,x\nend_of_record\n', 'not an integer');
      expectFailure('SF:a.dart\nDA:1,1\nLF:1\nLF:1\nend_of_record\n', 'LF:');
      expectFailure(
        'SF:a.dart\nDA:1,1,4\nend_of_record\n'
            'SF:a.dart\nDA:1,1,5\nend_of_record\n',
        'checksums',
      );
    });

    test('parses indented and CRLF traces into the same record', () async {
      const indented = '''
  SF:lib/a.dart
  DA:2,0
  DA:1,1
  TN:suite
end_of_record
''';
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/lcov.info')
        ..writeAsStringSync(indented.replaceAll('\n', '\r\n'));

      final streamed = await CoverageDocument.parseStreaming(file);
      final parsed = CoverageDocument.parse(indented);

      expect(streamed, parsed);
      expect(streamed.hashCode, parsed.hashCode);
      expect(
        parsed.files.single.renderTrace(),
        'SF:lib/a.dart\nDA:2,0\nDA:1,1\nTN:suite\nend_of_record',
      );
      expect(parsed.files.single.renderTrace(), isNot(contains('\r')));
    });

    test('parses a trailing record that has no end_of_record', () async {
      const trace = '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,0
''';
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/lcov.info')
        ..writeAsStringSync(trace);

      final streamed = await CoverageDocument.parseStreaming(file);

      expect(streamed, CoverageDocument.parse(trace));
      expect(streamed.files, hasLength(2));
      expect(streamed.files.last.renderTrace(), endsWith('end_of_record'));
    });

    test('equates records by measurements and unrecognized lines', () {
      const ordered = '''
SF:lib/a.dart
DA:1,1
DA:2,0
BRDA:1,0,0,1
TN:suite
end_of_record
''';
      const reordered = '''
SF:lib/a.dart
BRDA:1,0,0,1
DA:2,0
DA:1,1
TN:suite
end_of_record
''';
      const otherName = '''
SF:lib/a.dart
DA:1,1
DA:2,0
BRDA:1,0,0,1
TN:other
end_of_record
''';

      final first = CoverageDocument.parse(ordered);
      final second = CoverageDocument.parse(reordered);

      expect(first, first);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(CoverageDocument.parse(otherName)));
      const source = CoverageSourceEntry(r'lib\a.dart');
      const preserved = CoveragePreservedEntry('DA:1,1');
      const unrecognized = CoverageUnrecognizedEntry('TN:suite');
      expect(source, const CoverageSourceEntry(r'lib\a.dart'));
      expect(
        source.hashCode,
        const CoverageSourceEntry(r'lib\a.dart').hashCode,
      );
      expect(
        // Distinct instances exercise the non-identical equality branch.
        // ignore: prefer_const_constructors
        CoverageSourceEntry('a.dart') == CoverageSourceEntry('a.dart'),
        isTrue,
      );
      expect(source, isNot(preserved));
      expect(preserved, const CoveragePreservedEntry('DA:1,1'));
      expect(
        preserved.hashCode,
        const CoveragePreservedEntry('DA:1,1').hashCode,
      );
      expect(preserved, isNot(const CoveragePreservedEntry('DA:2,0')));
      expect(unrecognized, const CoverageUnrecognizedEntry('TN:suite'));
      expect(
        unrecognized.hashCode,
        const CoverageUnrecognizedEntry('TN:suite').hashCode,
      );
      expect(unrecognized, isNot(const CoverageUnrecognizedEntry('TN:other')));
    });

    test('places files that share no parent under an empty root', () {
      const trace = '''
SF:a.dart
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
SF:/external.dart
DA:1,0
end_of_record
''';

      final document = CoverageDocument.parse(trace);
      final tree = document.tree;

      expect(tree.path, isEmpty);
      expect(tree.name, isEmpty);
      expect(tree.linesFound, document.linesFound);
      expect(tree.files.single.path, 'a.dart');
      expect(tree.files.single.name, 'a.dart');
      expect(tree.files.single, tree.files.single);
      expect(tree, CoverageDocument.parse(trace).tree);
      expect(tree.hashCode, CoverageDocument.parse(trace).tree.hashCode);
      expect(tree.directories.map((directory) => directory.path), ['lib', '/']);
      expect(
        CoverageDocument.parse('''
SF:/lib/a.dart
DA:1,1
end_of_record
''').tree.path,
        '/lib',
      );
    });

    test('splits a backslash path and collapses a single-child chain', () {
      const trace = r'''
SF:lib\src\deep\a.dart
DA:1,1
end_of_record
''';

      final tree = CoverageDocument.parse(trace).tree;

      expect(tree.path, 'lib/src/deep');
      expect(tree.directories, isEmpty);
      expect(tree.files.single.path, r'lib\src\deep\a.dart');
      expect(tree.files.single.name, 'a.dart');
    });

    test('keeps one drive root and one UNC root', () {
      const trace = r'''
SF:C:\proj\a.dart
DA:1,1
end_of_record
SF:C:/proj/b.dart
DA:1,0
end_of_record
SF:\\server\share\proj\c.dart
DA:1,1
end_of_record
SF://server/share/proj/d.dart
DA:1,0
end_of_record
''';

      final directories = CoverageDocument.parse(trace).tree.directories;

      expect(directories.map((directory) => directory.path), [
        'C:/proj',
        '//server/share/proj',
      ]);
      expect(directories.first.files.map((file) => file.path), [
        r'C:\proj\a.dart',
        'C:/proj/b.dart',
      ]);
      expect(directories.last.name, 'proj');
    });

    test('returns an empty document for an empty trace', () {
      final document = CoverageDocument.parse('');

      expect(document.files, isEmpty);
      expect(document.isEmpty, isTrue);
      expect(document.tree.path, isEmpty);
      expect(document.lineRate, isNull);
      expect(document.tree.lineRate, isNull);
      expect(document, document);
    });

    test('keeps a UNC root that has no further directory', () {
      const trace = r'''
SF:\\server\share\a.dart
DA:1,1
end_of_record
''';

      final tree = CoverageDocument.parse(trace).tree;

      expect(tree.path, '//server/share');
      expect(tree.name, 'share');
      expect(tree, isNot(CoverageDocument.parse('').tree));
    });

    test('propagates a trace file read error', () {
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      expect(
        CoverageDocument.parseStreaming(File(directory.path)),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('rejects a trailing malformed record while streaming', () async {
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/lcov.info')
        ..writeAsStringSync('DA:1,1\n');

      expect(
        CoverageDocument.parseStreaming(file),
        throwsA(isA<CoverageTraceFormatFailure>()),
      );
    });

    test('rejects an empty record while streaming', () async {
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/lcov.info')
        ..writeAsStringSync('end_of_record\n');

      expect(
        CoverageDocument.parseStreaming(file),
        throwsA(
          isA<CoverageTraceFormatFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('empty record'),
          ),
        ),
      );
    });
  });
}
