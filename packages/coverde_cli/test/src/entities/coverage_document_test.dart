import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_format_failure.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$CoverageDocument', () {
    test('parses line records and leaves function and branch data null', () {
      final modifiedAt = DateTime.utc(2026, 10, 15);
      const trace = '''
SF:lib/a.dart
DA:2,0
DA:1,1
LF:2
LH:1
end_of_record
SF:lib/src/b.dart
DA:3,4,7
end_of_record
''';

      final document = CoverageDocument.parse(
        trace,
        traceModifiedAt: modifiedAt,
      );

      expect(document.traceModifiedAt, modifiedAt);
      expect(document.linesHit, 2);
      expect(document.linesFound, 3);
      expect(document.lineRate, 200 / 3);
      expect(document.functionRate, isNull);
      expect(document.branchRate, isNull);
      expect(document.files.map((file) => file.path), [
        'lib/a.dart',
        'lib/src/b.dart',
      ]);
      expect(document.files.first.functions, isNull);
      expect(document.files.first.branches, isNull);
      expect(document.files.first.lines, const [
        CoverageLine(number: 1, hits: 1),
        CoverageLine(number: 2, hits: 0),
      ]);
      expect(document.files.last.lines.single.checksum, 7);
      expect(document.tree.path, 'lib');
      expect(document.isEmpty, isFalse);
      expect(document.tree.lineRate, document.lineRate);
      expect(document.tree.functionRate, isNull);
      expect(document.tree.branchRate, isNull);
      expect(document.tree.name, 'lib');
      expect(document.tree.directories.single.name, 'src');
      expect(document.tree.files.map((file) => file.path), ['lib/a.dart']);
      expect(document.tree.directories.single.path, 'lib/src');
      expect(
        document.tree.directories.single.files.single.path,
        'lib/src/b.dart',
      );
    });

    test('parses function and branch records', () {
      const trace = '''
TN:ignored
SF:lib/app.dart
FN:10,main
FNDA:2,main
FN:20,other
FNF:2
FNH:1
BRDA:10,0,0,3
BRDA:10,0,1,-
BRF:2
BRH:1
DA:10,2
LF:1
LH:1
end_of_record
''';

      final document = CoverageDocument.parse(trace);
      final file = document.files.single;

      expect(
        file.functions,
        CoverageFunctions(
          hit: 1,
          found: 2,
          functions: const [
            CoverageFunction(name: 'main', line: 10, hits: 2),
            CoverageFunction(name: 'other', line: 20, hits: 0),
          ],
        ),
      );
      expect(file.functionRate, 50);
      expect(document.tree.functionRate, 50);
      expect(
        file.branches,
        CoverageBranches(
          hit: 1,
          found: 2,
          branches: const [
            CoverageBranch(line: 10, block: 0, branch: 0, taken: 3),
            CoverageBranch(line: 10, block: 0, branch: 1, taken: null),
          ],
        ),
      );
      expect(file.branchRate, 50);
      expect(document.branchRate, 50);
      expect(document.tree.branchRate, 50);
    });

    test('keeps the function name when an optional end line is present', () {
      const trace = '''
SF:lib/app.dart
FN:10,12,main
FNDA:1,main
FN:4,20
FN:8,foo,bar
FNDA:0,foo,bar
FNF:3
FNH:1
end_of_record
''';

      final functions =
          CoverageDocument.parse(trace).files.single.functions!.functions;

      expect(functions, const [
        CoverageFunction(name: '20', line: 4, hits: 0),
        CoverageFunction(name: 'foo,bar', line: 8, hits: 0),
        CoverageFunction(name: 'main', line: 10, hits: 1),
      ]);
    });

    test(
      'keeps a reported empty function group distinct from missing data',
      () {
        const trace = '''
SF:lib/empty.dart
FNF:0
FNH:0
DA:1,1
LF:1
LH:1
end_of_record
''';

        final file = CoverageDocument.parse(trace).files.single;

        expect(
          file.functions,
          CoverageFunctions(hit: 0, found: 0, functions: const []),
        );
        expect(file.functionRate, isNull);
        expect(file.branches, isNull);
        expect(file.branchRate, isNull);
      },
    );

    test('merges records that share a source path', () async {
      const trace = '''
TN:first
SF:lib/a.dart
DA:1,1,7
DA:2,1
DA:3,1,4
FN:1,main
FNDA:1,main
BRDA:1,0,0,-
BRDA:1,0,1,3
BRDA:1,0,2,1
end_of_record
TN:second
SF:lib/a.dart
DA:1,1,7
DA:2,0,9
DA:3,1
FN:1,main
FNDA:2,main
FN:4,other
BRDA:1,0,0,2
BRDA:1,0,1,-
BRDA:1,0,2,4
BRDA:2,1,0,4
end_of_record
SF:lib/add-functions.dart
DA:1,1
end_of_record
SF:lib/add-functions.dart
FN:1,main
FNDA:1,main
end_of_record
SF:lib/keep-functions.dart
FN:1,main
FNDA:1,main
DA:1,1
end_of_record
SF:lib/keep-functions.dart
DA:2,0
end_of_record
SF:lib/add-branches.dart
DA:1,1
end_of_record
SF:lib/add-branches.dart
BRDA:1,0,0,1
end_of_record
SF:lib/keep-branches.dart
BRDA:1,0,0,-
DA:1,1
end_of_record
SF:lib/keep-branches.dart
DA:2,1
end_of_record
''';
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/merged.lcov')
        ..writeAsStringSync(trace);

      final document = CoverageDocument.parse(trace);
      final streamed = await CoverageDocument.parseStreaming(file);

      expect(streamed.files.map((parsed) => parsed.path), [
        'lib/a.dart',
        'lib/add-functions.dart',
        'lib/keep-functions.dart',
        'lib/add-branches.dart',
        'lib/keep-branches.dart',
      ]);
      expect(streamed, document);

      final merged = document.files.first;
      expect(merged.raw, contains('TN:first'));
      expect(merged.raw, contains('TN:second'));
      expect(merged.lines, const [
        CoverageLine(number: 1, hits: 2, checksum: 7),
        CoverageLine(number: 2, hits: 1, checksum: 9),
        CoverageLine(number: 3, hits: 2, checksum: 4),
      ]);
      expect(merged.linesFound, 3);
      expect(merged.functions!.functions, const [
        CoverageFunction(name: 'main', line: 1, hits: 3),
        CoverageFunction(name: 'other', line: 4, hits: 0),
      ]);
      expect(merged.branches!.branches, const [
        CoverageBranch(line: 1, block: 0, branch: 0, taken: 2),
        CoverageBranch(line: 1, block: 0, branch: 1, taken: 3),
        CoverageBranch(line: 1, block: 0, branch: 2, taken: 5),
        CoverageBranch(line: 2, block: 1, branch: 0, taken: 4),
      ]);
      expect(
        document.files[1].functions!.functions.single,
        const CoverageFunction(name: 'main', line: 1, hits: 1),
      );
      expect(document.files[2].functions!.functions.single.hits, 1);
      expect(document.files[2].linesFound, 2);
      expect(document.files[3].branches!.branches.single.taken, 1);
      expect(document.files[4].branches!.branches.single.taken, isNull);
      expect(document.files[4].linesFound, 2);
    });

    test(
      'keeps a relative file and an absolute file in separate directories',
      () {
        const trace = '''
SF:local.dart
DA:1,1
end_of_record
SF:/external.dart
DA:1,0
end_of_record
''';

        final document = CoverageDocument.parse(trace);
        final tree = document.tree;

        expect(document.linesHit, 1);
        expect(document.linesFound, 2);
        expect(document.lineRate, 50);
        expect(tree.path, isEmpty);
        expect(tree.linesFound, 2);
        expect(tree.files.single.path, 'local.dart');
        expect(tree.directories.single.path, '/');
        expect(tree.directories.single.files.single.path, '/external.dart');
      },
    );

    test('uses an empty root path when files do not share a parent', () {
      const trace = '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:bin/b.dart
DA:1,0
end_of_record
''';

      final tree = CoverageDocument.parse(trace).tree;

      expect(tree.path, isEmpty);
      expect(tree.directories.map((directory) => directory.path), [
        'lib',
        'bin',
      ]);
      expect(tree.files, isEmpty);
    });

    test('collapses a single-child directory chain', () {
      const trace = '''
SF:lib/src/deep/a.dart
DA:1,1
end_of_record
''';

      final tree = CoverageDocument.parse(trace).tree;

      expect(tree.path, 'lib/src/deep');
      expect(tree.directories, isEmpty);
      expect(tree.files.single.name, 'a.dart');
    });

    test('normalizes Windows separators', () {
      const trace = r'''
SF:lib\src\a.dart
DA:1,1
end_of_record
''';

      final file = CoverageDocument.parse(trace).files.single;

      expect(file.path, 'lib/src/a.dart');
      expect(file.name, 'a.dart');
    });

    test('returns an empty document for an empty trace', () {
      final document = CoverageDocument.parse('');

      expect(document.files, isEmpty);
      expect(document.isEmpty, isTrue);
      expect(document.tree.path, isEmpty);
      expect(document.lineRate, isNull);
      expect(document.branchRate, isNull);
    });

    test('rejects a line-hit summary that disagrees with DA records', () {
      const trace = '''
SF:lib/a.dart
DA:1,0
DA:2,1
LF:2
LH:0
end_of_record
''';

      expect(
        () => CoverageDocument.parse(trace),
        throwsA(
          isA<CoverageTraceFormatFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('LH:0'),
          ),
        ),
      );
    });

    test('rejects a line-found summary that disagrees with DA records', () {
      const trace = '''
SF:lib/a.dart
DA:1,1
LF:2
LH:1
end_of_record
''';

      expect(
        () => CoverageDocument.parse(trace),
        throwsA(
          isA<CoverageTraceFormatFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('LF:2'),
          ),
        ),
      );
    });

    test('rejects a record that never closes', () {
      const trace = '''
SF:lib/a.dart
DA:1,1
''';

      expect(
        () => CoverageDocument.parse(trace),
        throwsA(isA<CoverageTraceFormatFailure>()),
      );
    });

    test('equates documents that parse to the same records', () {
      const trace = '''
SF:lib/a.dart
FN:10,main
FNDA:1,main
BRDA:10,0,0,1
DA:10,1
end_of_record
SF:lib/src/b.dart
DA:1,0
end_of_record
''';
      final modifiedAt = DateTime.utc(2026, 10, 15);
      final first = CoverageDocument.parse(trace, traceModifiedAt: modifiedAt);
      final second = CoverageDocument.parse(trace, traceModifiedAt: modifiedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, first);
      expect(first == Object(), isFalse);
      expect(first.files.first == first.files.last, isFalse);
      expect(first.tree == Object(), isFalse);
      expect(first.tree, second.tree);
      expect(first.tree.hashCode, second.tree.hashCode);
      expect(first.files, second.files);
      expect(first.files.first.hashCode, second.files.first.hashCode);
      expect(first.files.first.lines, second.files.first.lines);
      expect(
        first.files.first.lines.single.hashCode,
        second.files.first.lines.single.hashCode,
      );
      expect(first.files.first.functions, second.files.first.functions);
      expect(
        first.files.first.functions.hashCode,
        second.files.first.functions.hashCode,
      );
      expect(
        first.files.first.functions!.functions.single,
        second.files.first.functions!.functions.single,
      );
      expect(
        first.files.first.functions!.functions.single.hashCode,
        second.files.first.functions!.functions.single.hashCode,
      );
      expect(first.files.first.branches, second.files.first.branches);
      expect(
        first.files.first.branches.hashCode,
        second.files.first.branches.hashCode,
      );
      expect(
        first.files.first.branches!.branches.single,
        second.files.first.branches!.branches.single,
      );
      expect(
        first.files.first.branches!.branches.single.hashCode,
        second.files.first.branches!.branches.single.hashCode,
      );
    });

    test('rejects malformed trace records', () {
      const cases = <String, String>{
        '''
SF:lib/a.dart
DA:1,1,1
end_of_record
SF:lib/a.dart
DA:1,1,2
end_of_record
''':
            'checksums',
        '''
SF:lib/a.dart
FN:1,main
end_of_record
SF:lib/a.dart
FN:2,main
end_of_record
''':
            'repeats function `main`',
        '''
DA:1,1
end_of_record
''':
            'missing an `SF:`',
        '''
SF:lib/a.dart
DA:1,1
DA:1,0
end_of_record
''':
            'repeats line 1',
        '''
SF:lib/a.dart
FNDA:1,main
FNDA:0,main
DA:1,1
end_of_record
''':
            'repeats function `main`',
        '''
SF:lib/a.dart
FN:1,main
FN:2,main
DA:1,1
end_of_record
''':
            'repeats function `main`',
        '''
SF:lib/a.dart
FN:1,main
FNF:2
DA:1,1
end_of_record
''':
            'FNF:2',
        '''
SF:lib/a.dart
FNDA:1,main
FNH:0
DA:1,1
end_of_record
''':
            'FNH:0',
        '''
SF:lib/a.dart
BRDA:1,0,0,1
BRF:2
DA:1,1
end_of_record
''':
            'BRF:2',
        '''
SF:lib/a.dart
BRDA:1,0,0,-
BRH:1
DA:1,1
end_of_record
''':
            'BRH:1',
        '''
SF:lib/a.dart
DA:1
end_of_record
''':
            'Invalid `DA:`',
        '''
SF:lib/a.dart
BRDA:1,0,0
DA:1,1
end_of_record
''':
            'Invalid `BRDA:`',
        '''
SF:lib/a.dart
FNDA:1
DA:1,1
end_of_record
''':
            'Invalid `FNDA:`',
        '''
SF:lib/a.dart
LF:1
LF:1
DA:1,1
end_of_record
''':
            'repeats `LF:`',
        '''
SF:lib/a.dart
FN:0,main
DA:1,1
end_of_record
''':
            'positive line number',
        '''
SF:lib/a.dart
FN:10,12,
DA:1,1
end_of_record
''':
            'Invalid `FN:`',
        '''
SF:lib/a.dart
DA:1,-1
end_of_record
''':
            'must not be negative',
        '''
SF:lib/a.dart
DA:1,nope
end_of_record
''':
            'not an integer',
      };

      for (final entry in cases.entries) {
        expect(
          () => CoverageDocument.parse(entry.key),
          throwsA(
            isA<CoverageTraceFormatFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains(entry.value),
            ),
          ),
          reason: entry.value,
        );
      }
    });

    test('drops a record that has no line, function, or branch data', () {
      const trace = '''
SF:lib/empty.dart
TN:ignored
end_of_record
SF:lib/fn.dart
FN:4,only
end_of_record
SF:lib/br.dart
BRDA:8,0,0,-
end_of_record
''';

      final document = CoverageDocument.parse(trace);

      expect(document.files.map((file) => file.path), [
        'lib/fn.dart',
        'lib/br.dart',
      ]);
      expect(document.files.first.lineRate, isNull);
      expect(document.files.first.linesFound, 0);
      expect(document.lineRate, isNull);
      expect(document.files.first.functions!.functions.single.hits, 0);
      expect(document.files.last.branches!.branches.single.taken, isNull);
    });

    test('keeps the original record text and parses a stream', () async {
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/lcov.info');
      const trace = r'''
SF:lib\a.dart
FN:10,main
FNDA:1,main
DA:10,1
end_of_record
SF:ignored.dart
end_of_record
''';
      file.writeAsStringSync(trace);

      final streamed = await CoverageDocument.parseStreaming(
        file,
        traceModifiedAt: DateTime.utc(2026, 10, 15),
      );
      final parsed = CoverageDocument.parse(
        trace,
        traceModifiedAt: DateTime.utc(2026, 10, 15),
      );

      expect(streamed, parsed);
      expect(streamed.files.single.raw, contains(r'SF:lib\a.dart'));
      expect(streamed.files.single.raw, endsWith('end_of_record'));
      expect(streamed.files.single.path, 'lib/a.dart');
    });

    test('places a file with no directory on the empty root', () {
      const trace = '''
SF:a.dart/
DA:1,1
end_of_record
''';

      final tree = CoverageDocument.parse(trace).tree;

      expect(tree.path, isEmpty);
      expect(tree.name, isEmpty);
      expect(tree.files.single.path, 'a.dart');
      expect(tree.files.single.name, 'a.dart');
    });

    test(
      'parses a function known only from FNDA and an empty branch group',
      () {
        const trace = '''
SF:lib/a.dart
FNDA:3,main
BRF:0
BRH:0
DA:1,1
end_of_record
''';

        final file = CoverageDocument.parse(trace).files.single;

        expect(
          file.functions!.functions.single,
          const CoverageFunction(name: 'main', line: null, hits: 3),
        );
        expect(
          file.branches,
          CoverageBranches(hit: 0, found: 0, branches: const []),
        );
        expect(file.branchRate, isNull);
      },
    );

    test('propagates a trace file read error', () {
      expect(
        CoverageDocument.parseStreaming(
          File('missing-coverde-trace-file.lcov'),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('rejects malformed records while streaming', () async {
      final directory = Directory.systemTemp.createTempSync(
        'coverde-coverage-document-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      Future<void> expectFailure(String name, String trace, String message) {
        final file = File('${directory.path}/$name')..writeAsStringSync(trace);
        return expectLater(
          CoverageDocument.parseStreaming(file),
          throwsA(
            isA<CoverageTraceFormatFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains(message),
            ),
          ),
        );
      }

      await expectFailure('open.lcov', '''
SF:lib/a.dart
DA:1,1
''', 'end_of_record');
      await expectFailure('empty.lcov', 'end_of_record\n', 'empty record');
    });
  });
}
