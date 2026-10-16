// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors
// Non-const list literals for the same reason.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:coverde/src/entities/coverage_function.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverageFunction', () {
    test('stores a name, a start line, and a hit count', () {
      final function = CoverageFunction(name: 'main', line: 10, hits: 2);

      expect(function.name, 'main');
      expect(function.line, 10);
      expect(function.hits, 2);
    });

    test('allows a function known only from an execution record', () {
      final function = CoverageFunction(name: 'main', line: null, hits: 1);

      expect(function.line, isNull);
    });

    test('equates functions with the same name, line, and hits', () {
      final subject = CoverageFunction(name: 'main', line: 10, hits: 2);
      final same = CoverageFunction(name: 'main', line: 10, hits: 2);

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(
        subject,
        isNot(CoverageFunction(name: 'other', line: 10, hits: 2)),
      );
      expect(subject, isNot(CoverageFunction(name: 'main', line: 11, hits: 2)));
      expect(
        subject,
        isNot(CoverageFunction(name: 'main', line: null, hits: 2)),
      );
      expect(subject, isNot(CoverageFunction(name: 'main', line: 10, hits: 0)));
      expect(subject == Object(), isFalse);
    });
  });

  group('$CoverageFunctions', () {
    test('keeps the function list in the given order', () {
      final main = CoverageFunction(name: 'main', line: 1, hits: 1);
      final other = CoverageFunction(name: 'other', line: 4, hits: 0);
      final group = CoverageFunctions(
        hit: 1,
        found: 2,
        functions: [main, other],
      );

      expect(group.hit, 1);
      expect(group.found, 2);
      expect(group.functions, [main, other]);
      expect(() => group.functions.add(main), throwsUnsupportedError);
    });

    test('copies the function list', () {
      final function = CoverageFunction(name: 'main', line: 1, hits: 1);
      final input = [function];
      final group = CoverageFunctions(hit: 1, found: 1, functions: input);

      input.clear();

      expect(group.functions, [function]);
    });

    test('keeps an empty group distinct from a missing group', () {
      final group = CoverageFunctions(hit: 0, found: 0, functions: const []);

      expect(group.found, 0);
      expect(group.functions, isEmpty);
    });

    test('equates groups with the same counts and functions', () {
      final function = CoverageFunction(name: 'main', line: 1, hits: 1);
      final subject = CoverageFunctions(
        hit: 1,
        found: 1,
        functions: [function],
      );
      final same = CoverageFunctions(hit: 1, found: 1, functions: [function]);

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(
        subject,
        isNot(CoverageFunctions(hit: 0, found: 1, functions: [function])),
      );
      expect(
        subject,
        isNot(CoverageFunctions(hit: 1, found: 2, functions: [function])),
      );
      expect(
        subject,
        isNot(
          CoverageFunctions(
            hit: 1,
            found: 1,
            functions: [CoverageFunction(name: 'other', line: 1, hits: 1)],
          ),
        ),
      );
      expect(subject == Object(), isFalse);
    });
  });
}
