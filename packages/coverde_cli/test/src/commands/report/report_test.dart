import 'dart:convert';

import 'package:args/command_runner.dart';
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
  DateTime lastModifiedSync() => DateTime(2026, 11, 25);

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw FileSystemException('denied', path);
  }
}

void main() {
  group('coverde report', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      packageVersionManager = _MockPackageVersionManager();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: packageVersionManager,
      );
    });

    test('requires a report', () {
      final command = cmdRunner.commands['report']! as ReportCommand;
      expect(command.subcommands['lcov-html'], isA<LcovHtmlCommand>());
      expect(command.aliases, ['r']);
      expect(command.takesArguments, isFalse);
      expect(command.processManager, same(cmdRunner.processManager));
      expect(
        () => cmdRunner.run(const ['report']),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            contains('Missing subcommand'),
          ),
        ),
      );
    });

    test('rejects an unknown report', () {
      expect(
        () => cmdRunner.run(const ['report', 'missing']),
        throwsA(
          isA<UsageException>().having(
            (error) => error.message,
            'message',
            contains('Could not find a subcommand'),
          ),
        ),
      );
    });

    test('description names the report choice', () {
      expect(ReportCommand().description, contains('coverde report'));
    });

    test('lcov-html writes the report and prints its location', () async {
      final project = _project(
        trace: _trace('lib/a.dart'),
        sources: {'lib/a.dart': 'void main() {}\n'},
      );
      addTearDown(() => project.deleteSync(recursive: true));

      await IOOverrides.runZoned(
        () => cmdRunner.run(const ['r', 'lcov-html']),
        getCurrentDirectory: () => project,
      );

      final index = File(
        p.join(project.path, 'coverage', 'html', 'index.html'),
      );
      expect(index.existsSync(), isTrue);
      expect(index.readAsStringSync(), contains('lib/index.html'));
      verify(
        () => logger.info(
          any(
            that: allOf(
              contains('Report location:'),
              contains(index.absolute.path),
            ),
          ),
        ),
      ).called(1);
    });

    test('lcov-html merges traces and accepts absolute paths', () async {
      final project = _project(
        trace: _trace('lib/a.dart'),
        sources: {
          'lib/a.dart': 'void main() {}\n',
          'lib/b.dart': 'void other() {}\n',
        },
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final first = File(p.join(project.path, 'coverage', 'lcov.info'))
        ..setLastModifiedSync(DateTime(2026));
      final second = File(p.join(project.path, 'other.lcov.info'))
        ..writeAsStringSync(_trace('lib/b.dart'))
        ..setLastModifiedSync(DateTime(2026, 6, 2));
      final output = Directory(p.join(project.path, 'out'))..createSync();

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'report',
          'lcov-html',
          '--${LcovHtmlCommand.inputOption}',
          first.path,
          '--${LcovHtmlCommand.inputOption}',
          second.path,
          '--${LcovHtmlCommand.outputOption}',
          output.path,
          '--${LcovHtmlCommand.mediumOption}',
          '80',
          '--${LcovHtmlCommand.highOption}',
          '95',
        ]),
        getCurrentDirectory: () => project,
      );

      final directoryPage = File(
        p.join(output.path, 'lib', 'index.html'),
      ).readAsStringSync();
      expect(directoryPage, contains('a.dart'));
      expect(directoryPage, contains('b.dart'));
    });

    test('lcov-html rejects a missing trace', () async {
      final project = _project(trace: '');
      addTearDown(() => project.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run([
            'report',
            'lcov-html',
            '--${LcovHtmlCommand.inputOption}',
            'missing.info',
          ]),
          throwsA(isA<CoverdeReportTraceFileNotFoundFailure>()),
        );
      }, getCurrentDirectory: () => project);
    });

    test('lcov-html rejects an empty trace', () async {
      final project = _project(trace: '');
      addTearDown(() => project.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(const ['report', 'lcov-html']),
          throwsA(
            isA<CoverdeReportEmptyTraceFileFailure>().having(
              (failure) => failure.traceFilePath,
              'traceFilePath',
              contains('lcov.info'),
            ),
          ),
        );
      }, getCurrentDirectory: () => project);
    });

    test('lcov-html rejects a trace that cannot be read', () async {
      final project = _project(trace: _trace('lib/a.dart'));
      addTearDown(() => project.deleteSync(recursive: true));
      final tracePath = p.join(project.path, 'coverage', 'lcov.info');

      await IOOverrides.runZoned(
        () async {
          expect(
            () => cmdRunner.run([
              'report',
              'lcov-html',
              '--${LcovHtmlCommand.inputOption}',
              tracePath,
            ]),
            throwsA(isA<CoverdeReportTraceFileReadFailure>()),
          );
        },
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') return _UnreadTrace(path);
          return File(path);
        },
      );
    });

    test('lcov-html rejects a coverage path this host cannot open', () async {
      final sourcePath = Platform.isWindows ? '/lib/a.dart' : r'C:\lib\a.dart';
      final project = _project(trace: _trace(sourcePath));
      addTearDown(() => project.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(const ['report', 'lcov-html']),
          throwsA(
            isA<CoverdeReportUnresolvedCoveragePathFailure>().having(
              (failure) => failure.sourcePath,
              'sourcePath',
              sourcePath,
            ),
          ),
        );
      }, getCurrentDirectory: () => project);
    });

    test('lcov-html rejects a missing source file', () async {
      final project = _project(trace: _trace('lib/missing.dart'));
      addTearDown(() => project.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(const ['report', 'lcov-html']),
          throwsA(
            isA<CoverdeReportFileReadFailure>().having(
              (failure) => failure.filePath,
              'filePath',
              contains('missing.dart'),
            ),
          ),
        );
      }, getCurrentDirectory: () => project);
    });

    for (final entry in const [
      ('medium', 'nope'),
      ('medium', '-1'),
      ('medium', '101'),
      ('high', 'nope'),
      ('high', '-1'),
      ('high', '101'),
    ]) {
      test('lcov-html rejects ${entry.$1} ${entry.$2}', () {
        expect(
          () =>
              cmdRunner.run(['report', 'lcov-html', '--${entry.$1}', entry.$2]),
          throwsA(isA<CoverdeReportFailure>()),
        );
      });
    }

    for (final high in ['80', '90']) {
      test('lcov-html rejects medium 90 with high $high', () {
        expect(
          () => cmdRunner.run([
            'report',
            'lcov-html',
            '--${LcovHtmlCommand.mediumOption}',
            '90',
            '--${LcovHtmlCommand.highOption}',
            high,
          ]),
          throwsA(isA<CoverdeReportInvalidThresholdRelationshipFailure>()),
        );
      });
    }
  });
}

Directory _project({
  required String trace,
  Map<String, String> sources = const {},
}) {
  final directory = Directory.systemTemp.createTempSync('coverde-report-');
  for (final source in sources.entries) {
    final file = File(p.join(directory.path, source.key));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(source.value);
  }
  final traceFile = File(p.join(directory.path, 'coverage', 'lcov.info'));
  traceFile.parent.createSync(recursive: true);
  traceFile.writeAsStringSync(trace);
  return directory;
}

String _trace(String sourcePath) {
  return '''
TN:sample
SF:$sourcePath
DA:1,1
LF:1
LH:1
end_of_record
''';
}
