// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/entities/coverage_line.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverageLine', () {
    test('stores the line number, hits, and checksum', () {
      final line = CoverageLine(number: 4, hits: 2, checksum: 9);

      expect(line.number, 4);
      expect(line.hits, 2);
      expect(line.checksum, 9);
    });

    test('leaves the checksum null when it is omitted', () {
      final line = CoverageLine(number: 1, hits: 0);

      expect(line.checksum, isNull);
    });

    test('equates lines with the same number, hits, and checksum', () {
      final subject = CoverageLine(number: 4, hits: 2, checksum: 9);
      final same = CoverageLine(number: 4, hits: 2, checksum: 9);

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isNot(CoverageLine(number: 5, hits: 2, checksum: 9)));
      expect(subject, isNot(CoverageLine(number: 4, hits: 0, checksum: 9)));
      expect(subject, isNot(CoverageLine(number: 4, hits: 2)));
      expect(subject, isNot(CoverageLine(number: 4, hits: 2, checksum: 3)));
      expect(subject == Object(), isFalse);
    });
  });
}
