import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:test/test.dart';

void main() {
  group('$FileCoverageLogLevel', () {
    test('values', () {
      final names = () {
        return [
          'none',
          'overview',
          'lineNumbers',
          'lineContent',
        ];
      }();
      expect(
        FileCoverageLogLevel.values,
        names.map(
          (name) => FileCoverageLogLevel.values.byName(name),
        ),
      );
    });

    test('identifier', () {
      final map = {
        FileCoverageLogLevel.none: 'none',
        FileCoverageLogLevel.overview: 'overview',
        FileCoverageLogLevel.lineNumbers: 'line-numbers',
        FileCoverageLogLevel.lineContent: 'line-content',
      };
      for (final MapEntry(key: level, value: identifier) in map.entries) {
        expect(
          level.identifier,
          identifier,
          reason: '$level should have identifier `$identifier`',
        );
      }
    });
  });
}
