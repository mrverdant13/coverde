// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverageSourceEntry', () {
    test('equates every source entry', () {
      final subject = CoverageSourceEntry();
      final same = CoverageSourceEntry();

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isA<CoverageTraceEntry>());
      expect(subject == CoveragePreservedEntry('DA:1,1'), isFalse);
    });
  });

  group('$CoveragePreservedEntry', () {
    test('stores the trimmed line', () {
      final entry = CoveragePreservedEntry('FN:10,12,main');

      expect(entry.text, 'FN:10,12,main');
    });

    test('equates preserved lines with the same text', () {
      final subject = CoveragePreservedEntry('DA:1,1');
      final same = CoveragePreservedEntry('DA:1,1');

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isNot(CoveragePreservedEntry('DA:2,0')));
      expect(subject == CoverageUnrecognizedEntry('DA:1,1'), isFalse);
    });
  });

  group('$CoverageUnrecognizedEntry', () {
    test('stores the trimmed line', () {
      final entry = CoverageUnrecognizedEntry('TN:suite');

      expect(entry.text, 'TN:suite');
    });

    test('equates unrecognized lines with the same text', () {
      final subject = CoverageUnrecognizedEntry('TN:suite');
      final same = CoverageUnrecognizedEntry('TN:suite');

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isNot(CoverageUnrecognizedEntry('TN:other')));
      expect(subject == CoverageSourceEntry(), isFalse);
    });
  });
}
