import 'package:coverde/src/entities/coverage_rate.dart';
import 'package:test/test.dart';

void main() {
  group('coverageRate', () {
    test('returns null when nothing was found', () {
      expect(coverageRate(hit: 0, found: 0), isNull);
    });

    test('returns the percentage of hits', () {
      expect(coverageRate(hit: 1, found: 4), 25);
      expect(coverageRate(hit: 0, found: 2), 0);
      expect(coverageRate(hit: 2, found: 2), 100);
    });
  });

  group('optionalCoverageRate', () {
    test('returns null when either count is absent', () {
      expect(optionalCoverageRate(hit: null, found: 2), isNull);
      expect(optionalCoverageRate(hit: 1, found: null), isNull);
      expect(optionalCoverageRate(hit: null, found: null), isNull);
    });

    test('returns null when the measurement found nothing', () {
      expect(optionalCoverageRate(hit: 0, found: 0), isNull);
    });

    test('returns the percentage when both counts are present', () {
      expect(optionalCoverageRate(hit: 1, found: 2), 50);
    });
  });
}
