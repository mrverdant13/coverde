import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/check/log_coverage.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockPackageVersionManager extends Mock
    implements PackageVersionManager {}

final class _FakeCoverdeCommandRunner extends CoverdeCommandRunner {
  _FakeCoverdeCommandRunner({
    required super.logger,
    required super.packageVersionManager,
  });

  @override
  Future<void> run(Iterable<String> args) {
    return super.run([
      ...args,
      '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}''',
    ]);
  }
}

final class _UnreadTrace extends Fake implements File {
  _UnreadTrace(this.path);

  @override
  final String path;

  @override
  bool existsSync() => true;

  @override
  DateTime lastModifiedSync() => DateTime(2026, 11, 25);

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw FileSystemException('denied', path);
  }
}

void main() {
  group('coverde report console', () {
    late Logger logger;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: _MockPackageVersionManager(),
      );
    });

    test('is a report and value is gone', () {
      expect(ReportCommand().subcommands['console'], isA<ConsoleCommand>());
      expect(cmdRunner.commands.containsKey('value'), isFalse);
      expect(ConsoleCommand().takesArguments, isFalse);
    });

    for (final level in FileCoverageLogLevel.values) {
      test('prints ${level.identifier}', () async {
        final project = _fixtureProject();
        final trace = File(
          p.join(project.path, 'coverage', 'lcov.info'),
        ).readAsStringSync();
        final document = CoverageDocument.parse(trace);

        late final String expected;
        await IOOverrides.runZoned(() async {
          expected = _logged(document, level);
          await cmdRunner.run([
            'report',
            'console',
            '--${ConsoleCommand.fileCoverageLogLevelFlag}',
            level.identifier,
          ]);
        }, getCurrentDirectory: () => project);

        verify(() => logger.write(expected)).called(1);
      });
    }

    test(
      'prints n/a for a function-only trace and does not need its source',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-console-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final trace = File(p.join(directory.path, 'lcov.info'))
          ..writeAsStringSync('''
SF:lib/missing.dart
FN:1,main
FNDA:0,main
end_of_record
''');
        final document = CoverageDocument.parse(trace.readAsStringSync());

        await cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.inputOption}',
          trace.path,
        ]);

        final expected = _logged(document, FileCoverageLogLevel.lineContent);
        verify(() => logger.write(expected)).called(1);
      },
    );

    test('does not open a fully covered source path', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final sourcePath = Platform.isWindows
          ? '/lib/covered.dart'
          : r'C:\covered.dart';
      final trace = File(p.join(directory.path, 'lcov.info'))
        ..writeAsStringSync('''
SF:$sourcePath
DA:1,1
end_of_record
''');

      await cmdRunner.run([
        'report',
        'console',
        '--${ConsoleCommand.inputOption}',
        trace.path,
      ]);

      verify(
        () => logger.write(any(that: contains('100.00% - 1/1'))),
      ).called(1);
    });

    test('merges traces', () async {
      final project = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => project.deleteSync(recursive: true));
      File(p.join(project.path, 'lib', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      File(p.join(project.path, 'lib', 'b.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void other() {}\n');
      final first = File(p.join(project.path, 'first.lcov.info'))
        ..writeAsStringSync('SF:lib/a.dart\nDA:1,1\nend_of_record\n');
      final second = File(p.join(project.path, 'second.lcov.info'))
        ..writeAsStringSync('SF:lib/b.dart\nDA:1,0\nend_of_record\n');
      final merged = StringBuffer();
      appendTraceContent(merged, first.readAsStringSync());
      appendTraceContent(merged, second.readAsStringSync());
      final document = CoverageDocument.parse(merged.toString());

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.inputOption}',
          first.path,
          '--${ConsoleCommand.inputOption}',
          second.path,
          '--${ConsoleCommand.fileCoverageLogLevelFlag}',
          FileCoverageLogLevel.overview.identifier,
        ]),
        getCurrentDirectory: () => project,
      );

      final expected = _logged(document, FileCoverageLogLevel.overview);
      verify(() => logger.write(expected)).called(1);
    });

    test('rejects an empty trace', () async {
      final empty = File(
        p.join(
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'empty.lcov.info',
        ),
      );

      expect(
        () => cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.inputOption}',
          empty.path,
        ]),
        throwsA(
          isA<CoverdeReportEmptyTraceFileFailure>().having(
            (failure) => failure.traceFilePath,
            'traceFilePath',
            p.absolute(empty.path),
          ),
        ),
      );
    });

    test('rejects a missing trace', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final absent = p.join(directory.path, 'absent.lcov.info');

      expect(
        () => cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.inputOption}',
          absent,
        ]),
        throwsA(isA<CoverdeReportTraceFileNotFoundFailure>()),
      );
    });

    test('rejects a trace that cannot be read', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final tracePath = p.join(directory.path, 'lcov.info');
      File(
        tracePath,
      ).writeAsStringSync('SF:lib/a.dart\nDA:1,1\nend_of_record\n');

      await IOOverrides.runZoned(
        () async {
          expect(
            () => cmdRunner.run([
              'report',
              'console',
              '--${ConsoleCommand.inputOption}',
              tracePath,
            ]),
            throwsA(
              isA<CoverdeReportTraceFileReadFailure>().having(
                (failure) => failure.traceFilePath,
                'traceFilePath',
                p.absolute(tracePath),
              ),
            ),
          );
        },
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') return _UnreadTrace(path);
          return File(path);
        },
      );
    });

    test('rejects a coverage path this host cannot open', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final sourcePath = Platform.isWindows ? '/lib/a.dart' : r'C:\lib\a.dart';
      final trace = File(p.join(directory.path, 'lcov.info'))
        ..writeAsStringSync('SF:$sourcePath\nDA:1,0\nend_of_record\n');

      expect(
        () => cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.inputOption}',
          trace.path,
        ]),
        throwsA(
          isA<CoverdeReportUnresolvedCoveragePathFailure>().having(
            (failure) => failure.sourcePath,
            'sourcePath',
            sourcePath,
          ),
        ),
      );
    });

    test('rejects a missing source file at line-content', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-console-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final trace = File(p.join(directory.path, 'lcov.info'))
        ..writeAsStringSync('SF:lib/missing.dart\nDA:1,0\nend_of_record\n');

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run([
            'report',
            'console',
            '--${ConsoleCommand.inputOption}',
            trace.path,
          ]),
          throwsA(
            isA<CoverdeReportFileReadFailure>().having(
              (failure) => failure.filePath,
              'filePath',
              contains('missing.dart'),
            ),
          ),
        );
      }, getCurrentDirectory: () => directory);
    });

    test('rejects an unknown log level', () {
      expect(
        () => cmdRunner.run([
          'report',
          'console',
          '--${ConsoleCommand.fileCoverageLogLevelFlag}',
          'invalid-log-level',
        ]),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            contains('for option "--file-coverage-log-level"'),
          ),
        ),
      );
    });
  });
}

Directory _fixtureProject() {
  return Directory(
    p.join(
      'test',
      'src',
      'commands',
      'value',
      'fixtures',
      'partially_covered_proj',
    ),
  );
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
