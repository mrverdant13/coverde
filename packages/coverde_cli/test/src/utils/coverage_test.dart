import 'package:coverde/src/utils/coverage.dart';
import 'package:test/test.dart';

void main() {
  group('CoverageValue', () {
    group('checkedAsCoverage', () {
      test('| for negative values', () {
        const invalidCovValues = [-3, -1.3];
        for (final invalidCovValue in invalidCovValues) {
          num action() => invalidCovValue.checkedAsCoverage();
          expect(
            action,
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'The coverage value should be positive.',
              ),
            ),
          );
        }
      });

      test('| for values greater than 100', () {
        const invalidCovValues = [101, 103.6];
        for (final invalidCovValue in invalidCovValues) {
          num action() => invalidCovValue.checkedAsCoverage();
          expect(action, throwsA(isA<ArgumentError>()));
        }
      });

      test('| for valid values', () {
        const validCovValues = [0, 1, 55, 99, 100];
        for (final validCovValue in validCovValues) {
          final result = validCovValue.checkedAsCoverage();
          expect(result, validCovValue);
        }
      });
    });
  });

  test('optionalCoverageRate is null without a measurement', () {
    expect(optionalCoverageRate(hit: null, found: 1), isNull);
    expect(optionalCoverageRate(hit: 1, found: null), isNull);
    expect(optionalCoverageRate(hit: 0, found: 0), isNull);
    expect(optionalCoverageRate(hit: 1, found: 2), 50);
  });
}
