import 'package:coverde/src/features/reporting/templates/text_filters.dart';
import 'package:test/test.dart';

void main() {
  group('sortBy', () {
    test('keeps equal values in their previous order', () {
      final sorted = sortBy(
        [
          {'name': 'b', 'hits': 1},
          {'name': 'a', 'hits': 1},
        ],
        ['hits'],
        const {},
      );

      expect(sorted, [
        {'name': 'b', 'hits': 1},
        {'name': 'a', 'hits': 1},
      ]);
    });

    test('puts a null field after a value', () {
      final sorted = sortBy(
        [
          {'name': 'b', 'hits': 1},
          {'name': 'a', 'hits': null},
        ],
        ['hits'],
        const {},
      );

      expect(sorted, [
        {'name': 'b', 'hits': 1},
        {'name': 'a', 'hits': null},
      ]);
    });
  });

  group('sortByRate', () {
    test('puts a null rate first when asked', () {
      final sorted = sortByRate(
        [
          {'path': 'measured', 'branchRate': 0.5},
          {'path': 'missing', 'branchRate': null},
        ],
        ['branchRate', 'asc', 'first'],
        const {},
      );

      expect(sorted, [
        {'path': 'missing', 'branchRate': null},
        {'path': 'measured', 'branchRate': 0.5},
      ]);
    });

    test('keeps a leading null rate first when asked', () {
      final sorted = sortByRate(
        [
          {'path': 'missing', 'branchRate': null},
          {'path': 'measured', 'branchRate': 0.5},
        ],
        ['branchRate', 'asc', 'first'],
        const {},
      );

      expect(sorted, [
        {'path': 'missing', 'branchRate': null},
        {'path': 'measured', 'branchRate': 0.5},
      ]);
    });

    test('puts a null rate last by default', () {
      final sorted = sortByRate(
        [
          {'path': 'missing', 'branchRate': null},
          {'path': 'measured', 'branchRate': 0.5},
        ],
        ['branchRate'],
        const {},
      );

      expect(sorted, [
        {'path': 'measured', 'branchRate': 0.5},
        {'path': 'missing', 'branchRate': null},
      ]);
    });
  });
}
