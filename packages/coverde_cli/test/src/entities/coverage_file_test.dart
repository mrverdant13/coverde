// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors
// Non-const list literals for the same reason.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:test/test.dart';

void main() {
  CoverageFile sample({
    String path = 'lib/app.dart',
    List<CoverageTraceEntry>? entries,
    List<CoverageLine> lines = const [],
    CoverageFunctions? functions,
    CoverageBranches? branches,
  }) {
    return CoverageFile(
      path: path,
      entries:
          entries ??
          const [CoverageSourceEntry(), CoverageUnrecognizedEntry('TN:suite')],
      lines: lines,
      functions: functions,
      branches: branches,
    );
  }

  group('$CoverageFile', () {
    test('uses the last path segment as the name', () {
      expect(sample().name, 'app.dart');
      expect(sample(path: 'app.dart').name, 'app.dart');
      expect(sample(path: '/lib/app.dart').name, 'app.dart');
    });

    test('counts hit lines and leaves rates null when a group is absent', () {
      final file = sample(
        lines: [
          CoverageLine(number: 1, hits: 1),
          CoverageLine(number: 2, hits: 0),
        ],
      );

      expect(file.linesFound, 2);
      expect(file.linesHit, 1);
      expect(file.lineRate, 50);
      expect(file.functionRate, isNull);
      expect(file.branchRate, isNull);
      expect(
        () => file.lines.add(CoverageLine(number: 3, hits: 0)),
        throwsUnsupportedError,
      );
      expect(
        () => file.entries.add(CoverageSourceEntry()),
        throwsUnsupportedError,
      );
    });

    test('returns null rates when a present group found nothing', () {
      final file = sample(
        functions: CoverageFunctions(hit: 0, found: 0, functions: const []),
        branches: CoverageBranches(hit: 0, found: 0, branches: const []),
      );

      expect(file.lineRate, isNull);
      expect(file.functionRate, isNull);
      expect(file.branchRate, isNull);
    });

    test('returns function and branch rates from their groups', () {
      final file = sample(
        functions: CoverageFunctions(
          hit: 1,
          found: 2,
          functions: [
            CoverageFunction(name: 'main', line: 1, hits: 1),
            CoverageFunction(name: 'other', line: 2, hits: 0),
          ],
        ),
        branches: CoverageBranches(
          hit: 1,
          found: 2,
          branches: [
            CoverageBranch(line: 1, block: 0, branch: 0, taken: 1),
            CoverageBranch(line: 1, block: 0, branch: 1, taken: null),
          ],
        ),
      );

      expect(file.functionRate, 50);
      expect(file.branchRate, 50);
    });

    test('renders source entries from the file path or a replacement', () {
      final file = sample(
        entries: [
          CoverageUnrecognizedEntry('TN:suite'),
          CoverageSourceEntry(),
          CoveragePreservedEntry('DA:1,1'),
          CoveragePreservedEntry('end_of_record'),
          CoverageSourceEntry(),
        ],
      );

      expect(
        file.renderTrace(),
        'TN:suite\n'
        'SF:lib/app.dart\n'
        'DA:1,1\n'
        'end_of_record\n'
        'SF:lib/app.dart',
      );
      expect(
        file.renderTrace(path: 'src/app.dart'),
        'TN:suite\n'
        'SF:src/app.dart\n'
        'DA:1,1\n'
        'end_of_record\n'
        'SF:src/app.dart',
      );
    });

    test('keeps the separator from the original source path', () {
      final file = sample(
        entries: [
          CoverageSourceEntry(r'lib\app.dart'),
          CoveragePreservedEntry('DA:1,1'),
          CoveragePreservedEntry('end_of_record'),
        ],
      );

      expect(
        file.renderTrace(),
        'SF:lib\\app.dart\n'
        'DA:1,1\n'
        'end_of_record',
      );
      expect(
        file.renderTrace(path: r'src\app.dart'),
        'SF:src\\app.dart\n'
        'DA:1,1\n'
        'end_of_record',
      );
    });

    test('equates files by measurements and unrecognized lines', () {
      final lines = [CoverageLine(number: 1, hits: 1)];
      final functions = CoverageFunctions(
        hit: 1,
        found: 1,
        functions: [CoverageFunction(name: 'main', line: 1, hits: 1)],
      );
      final branches = CoverageBranches(
        hit: 1,
        found: 1,
        branches: [CoverageBranch(line: 1, block: 0, branch: 0, taken: 1)],
      );
      final subject = sample(
        lines: lines,
        functions: functions,
        branches: branches,
      );
      final same = sample(
        lines: [CoverageLine(number: 1, hits: 1)],
        functions: CoverageFunctions(
          hit: 1,
          found: 1,
          functions: [CoverageFunction(name: 'main', line: 1, hits: 1)],
        ),
        branches: CoverageBranches(
          hit: 1,
          found: 1,
          branches: [CoverageBranch(line: 1, block: 0, branch: 0, taken: 1)],
        ),
        entries: [
          CoveragePreservedEntry('DA:2,0'),
          CoverageSourceEntry(),
          CoverageUnrecognizedEntry('TN:suite'),
        ],
      );

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isNot(sample(path: 'lib/other.dart')));
      expect(subject, isNot(sample()));
      expect(subject, isNot(sample(lines: lines, branches: branches)));
      expect(subject, isNot(sample(lines: lines, functions: functions)));
      expect(
        subject,
        isNot(
          sample(
            lines: lines,
            functions: functions,
            branches: branches,
            entries: const [CoverageUnrecognizedEntry('TN:other')],
          ),
        ),
      );
      expect(subject == Object(), isFalse);
    });
  });
}
