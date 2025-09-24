// Not enforcing const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors

import 'package:coverde/src/entities/file_line_coverage_details.dart';
import 'package:test/test.dart';

void main() {
  group('$FileLineCoverageStatus', () {
    test('values', () {
      final names = () {
        return [
          'covered',
          'uncovered',
          'neutral',
        ];
      }();
      expect(
        FileLineCoverageStatus.values,
        names.map(
          (name) => FileLineCoverageStatus.values.byName(name),
        ),
      );
    });
  });

  group('$FileLineCoverageDetails', () {
    test('can be compared', () {
      final subject = FileLineCoverageDetails(
        lineNumber: 1,
        content: 'Content.',
        status: FileLineCoverageStatus.covered,
      );
      final same = FileLineCoverageDetails(
        lineNumber: 1,
        content: 'Content.',
        status: FileLineCoverageStatus.covered,
      );
      final other = FileLineCoverageDetails(
        lineNumber: 2,
        content: 'Other content.',
        status: FileLineCoverageStatus.neutral,
      );
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(subject, isNot(other));
      expect(subject.hashCode, isNot(other.hashCode));
    });
  });
}
