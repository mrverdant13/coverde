// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors
// Non-const list literals for the same reason.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:test/test.dart';

void main() {
  CoverageFile sourceFile({
    required String path,
    List<CoverageLine> lines = const [],
    CoverageFunctions? functions,
    CoverageBranches? branches,
  }) {
    return CoverageFile(
      path: path,
      entries: const [CoverageSourceEntry()],
      lines: lines,
      functions: functions,
      branches: branches,
    );
  }

  group('$CoverageDirectory', () {
    test('uses the last path segment as the name', () {
      CoverageDirectory directory(String path) {
        return CoverageDirectory(
          path: path,
          directories: const [],
          files: const [],
        );
      }

      expect(directory('').name, isEmpty);
      expect(directory('lib').name, 'lib');
      expect(directory('lib/src').name, 'src');
      expect(directory('/lib').name, 'lib');
      expect(directory('/').name, isEmpty);
    });

    test('sums line totals from child directories and files', () {
      final directory = CoverageDirectory(
        path: 'lib',
        directories: [
          CoverageDirectory(
            path: 'lib/src',
            directories: const [],
            files: [
              sourceFile(
                path: 'lib/src/a.dart',
                lines: [CoverageLine(number: 1, hits: 1)],
              ),
            ],
          ),
        ],
        files: [
          sourceFile(
            path: 'lib/b.dart',
            lines: [
              CoverageLine(number: 1, hits: 0),
              CoverageLine(number: 2, hits: 0),
            ],
          ),
        ],
      );

      expect(directory.linesFound, 3);
      expect(directory.linesHit, 1);
      expect(directory.lineRate, closeTo(100 / 3, 0.0001));
      expect(
        () => directory.files.add(sourceFile(path: 'lib/c.dart')),
        throwsUnsupportedError,
      );
      expect(
        () => directory.directories.add(
          CoverageDirectory(
            path: 'lib/bin',
            directories: const [],
            files: const [],
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('returns a null line rate when no lines were found', () {
      final directory = CoverageDirectory(
        path: '',
        directories: const [],
        files: [sourceFile(path: 'a.dart')],
      );

      expect(directory.linesFound, 0);
      expect(directory.lineRate, isNull);
    });

    test('sums function and branch totals and ignores unknown children', () {
      final directory = CoverageDirectory(
        path: 'lib',
        directories: [
          CoverageDirectory(
            path: 'lib/src',
            directories: const [],
            files: [
              sourceFile(
                path: 'lib/src/missing.dart',
                lines: [CoverageLine(number: 1, hits: 1)],
              ),
            ],
          ),
        ],
        files: [
          sourceFile(
            path: 'lib/a.dart',
            functions: CoverageFunctions(
              hit: 1,
              found: 2,
              functions: [
                CoverageFunction(name: 'main', line: 1, hits: 1),
                CoverageFunction(name: 'other', line: 2, hits: 0),
              ],
            ),
            branches: CoverageBranches(hit: 0, found: 0, branches: const []),
          ),
        ],
      );

      expect(directory.functionsHit, 1);
      expect(directory.functionsFound, 2);
      expect(directory.functionRate, 50);
      expect(directory.branchesHit, 0);
      expect(directory.branchesFound, 0);
      expect(directory.branchRate, isNull);
    });

    test(
      'leaves function and branch totals null when nobody reported them',
      () {
        final directory = CoverageDirectory(
          path: 'lib',
          directories: const [],
          files: [
            sourceFile(
              path: 'lib/a.dart',
              lines: [CoverageLine(number: 1, hits: 1)],
            ),
          ],
        );

        expect(directory.functionsHit, isNull);
        expect(directory.functionsFound, isNull);
        expect(directory.functionRate, isNull);
        expect(directory.branchesHit, isNull);
        expect(directory.branchesFound, isNull);
        expect(directory.branchRate, isNull);
      },
    );

    test('equates directories with the same path, children, and files', () {
      final file = sourceFile(
        path: 'lib/a.dart',
        lines: [CoverageLine(number: 1, hits: 1)],
      );
      final child = CoverageDirectory(
        path: 'lib/src',
        directories: const [],
        files: const [],
      );
      final subject = CoverageDirectory(
        path: 'lib',
        directories: [child],
        files: [file],
      );
      final same = CoverageDirectory(
        path: 'lib',
        directories: [
          CoverageDirectory(
            path: 'lib/src',
            directories: const [],
            files: const [],
          ),
        ],
        files: [
          sourceFile(
            path: 'lib/a.dart',
            lines: [CoverageLine(number: 1, hits: 1)],
          ),
        ],
      );

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(
        subject,
        isNot(
          CoverageDirectory(path: 'bin', directories: [child], files: [file]),
        ),
      );
      expect(
        subject,
        isNot(
          CoverageDirectory(path: 'lib', directories: const [], files: [file]),
        ),
      );
      expect(
        subject,
        isNot(
          CoverageDirectory(path: 'lib', directories: [child], files: const []),
        ),
      );
      expect(subject == Object(), isFalse);
    });
  });
}
