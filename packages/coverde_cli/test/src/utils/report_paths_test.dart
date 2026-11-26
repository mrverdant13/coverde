import 'package:coverde/src/utils/report_paths.dart';
import 'package:test/test.dart';

void main() {
  group('ReportPaths', () {
    test('relative from a directory is the path between them', () {
      final paths = ReportPaths();

      expect(paths.relative('lib/src/a.dart', from: 'lib'), 'src/a.dart');
    });

    test('skips a namespace that is already taken', () {
      final paths = ReportPaths()
        ..collectPaths([
          'absolute/local.dart',
          'absolute-2/other.dart',
          '/tmp/a.dart',
        ]);

      expect(paths.relative('/tmp/a.dart'), 'absolute-3/tmp/a.dart');
    });
  });
}
