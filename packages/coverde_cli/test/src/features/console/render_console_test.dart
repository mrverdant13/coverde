import 'package:coverde/src/commands/check/log_coverage.dart';
import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:coverde/src/features/console/render_console.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final class _MockLogger extends Mock implements Logger {}

void main() {
  final sources = FileCoverageSourceReader(open: (path) => File(path).absolute);

  test('matches the value command at every log level', () async {
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
    final document = CoverageDocument.parse(trace);

    await IOOverrides.runZoned(() async {
      for (final level in ConsoleReportLevel.values) {
        final rendered = await renderConsoleReport(
          document: document,
          sources: sources,
          level: level,
        );
        expect(
          rendered,
          _logged(document, _legacyLevel(level)),
          reason: level.identifier,
        );
      }
    }, getCurrentDirectory: () => project);
  });

  test('matches a fully covered file and a function-only file', () async {
    final directory = Directory.systemTemp.createTempSync('coverde-console-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File(p.join(directory.path, 'lib', 'covered.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final covered = CoverageDocument.parse('''
SF:lib/covered.dart
DA:1,1
end_of_record
''');
    final functions = CoverageDocument.parse('''
SF:lib/missing.dart
FN:1,main
FNDA:0,main
end_of_record
''');

    await IOOverrides.runZoned(() async {
      for (final level in ConsoleReportLevel.values) {
        expect(
          await renderConsoleReport(
            document: covered,
            sources: sources,
            level: level,
          ),
          _logged(covered, _legacyLevel(level)),
          reason: 'covered ${level.identifier}',
        );
        expect(
          await renderConsoleReport(
            document: functions,
            sources: sources,
            level: level,
          ),
          _logged(functions, _legacyLevel(level)),
          reason: 'functions ${level.identifier}',
        );
      }
    }, getCurrentDirectory: () => directory);
  });
}

FileCoverageLogLevel _legacyLevel(ConsoleReportLevel level) {
  return switch (level) {
    ConsoleReportLevel.lineContent => FileCoverageLogLevel.lineContent,
    ConsoleReportLevel.lineNumbers => FileCoverageLogLevel.lineNumbers,
    ConsoleReportLevel.overview => FileCoverageLogLevel.overview,
    ConsoleReportLevel.none => FileCoverageLogLevel.none,
  };
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
