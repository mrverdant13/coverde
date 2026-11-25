import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:coverde/src/features/check/render_check.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../oracle/log_coverage.dart';

final class _MockLogger extends Mock implements Logger {}

void main() {
  test('prints source for an uncovered file and the global rate alone '
      'when every line is covered', () async {
    final project = Directory(
      p.join(
        'test',
        'src',
        'commands',
        'value',
        'fixtures',
        'partially_covered_proj',
      ),
    );
    final trace = File(
      p.join(project.path, 'coverage', 'lcov.info'),
    ).readAsStringSync();
    final partial = CoverageDocument.parse(trace);
    final directory = Directory.systemTemp.createTempSync('coverde-check-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File(p.join(directory.path, 'lib', 'covered.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final covered = CoverageDocument.parse('''
SF:lib/covered.dart
DA:1,1
end_of_record
''');

    await IOOverrides.runZoned(() async {
      expect(
        await renderCheckReport(document: partial),
        _logged(partial, FileCoverageLogLevel.lineContent),
      );
    }, getCurrentDirectory: () => project);

    await IOOverrides.runZoned(() async {
      expect(
        await renderCheckReport(document: covered),
        _logged(covered, FileCoverageLogLevel.none),
      );
    }, getCurrentDirectory: () => directory);
  });

  test(
    'prints uncovered line numbers when the source cannot be read',
    () async {
      final directory = Directory.systemTemp.createTempSync('coverde-check-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final missing = CoverageDocument.parse('''
SF:lib/missing.dart
DA:1,0
DA:2,1
end_of_record
''');
      final unreadable = File(p.join(directory.path, 'lib', 'blocked.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void blocked() {}\n');
      Process.runSync('chmod', ['000', unreadable.path]);
      final blocked = CoverageDocument.parse('''
SF:${unreadable.path}
DA:3,0
end_of_record
''');
      final unresolved = CoverageDocument.parse('''
SF:${Platform.isWindows ? '/lib/missing.dart' : r'C:\lib\missing.dart'}
DA:4,0
end_of_record
''');

      await IOOverrides.runZoned(() async {
        expect(
          await renderCheckReport(document: missing),
          _logged(missing, FileCoverageLogLevel.lineNumbers),
        );
        expect(
          await renderCheckReport(document: blocked),
          _logged(blocked, FileCoverageLogLevel.lineNumbers),
        );
        expect(
          await renderCheckReport(document: unresolved),
          _logged(unresolved, FileCoverageLogLevel.lineNumbers),
        );
      }, getCurrentDirectory: () => directory);
    },
  );

  test('omits a fully covered file that shares a trace with a gap', () async {
    final directory = Directory.systemTemp.createTempSync('coverde-check-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File(p.join(directory.path, 'lib', 'gap.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void gap() {}\nvoid covered() {}\n');
    File(p.join(directory.path, 'lib', 'done.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void done() {}\n');
    final document = CoverageDocument.parse('''
SF:lib/done.dart
DA:1,1
end_of_record
SF:lib/gap.dart
DA:1,0
DA:2,1
end_of_record
''');

    await IOOverrides.runZoned(() async {
      final rendered = await renderCheckReport(document: document);
      expect(rendered, isNot(contains('done.dart')));
      expect(rendered, contains('lib/gap.dart'));
      expect(rendered, contains('GLOBAL:'));
    }, getCurrentDirectory: () => directory);
  });
}

String _logged(CoverageDocument document, FileCoverageLogLevel level) {
  final lines = <String>[];
  final logger = _MockLogger();
  when(() => logger.info(any())).thenAnswer((invocation) {
    lines.add(invocation.positionalArguments.single as String);
  });
  logCoverage(logger: logger, document: document, fileCoverageLogLevel: level);
  return '${lines.join('\n')}\n';
}
