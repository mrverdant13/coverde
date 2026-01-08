import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../helpers/test_files.dart';

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

void main() {
  group('coverde value', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(
      () {
        logger = _MockLogger();
        packageVersionManager = _MockPackageVersionManager();
        cmdRunner = _FakeCoverdeCommandRunner(
          logger: logger,
          packageVersionManager: packageVersionManager,
        );
      },
    );

    tearDown(
      () {
        // verifyNoMoreInteractions(logger);
      },
    );

    test(
      '| description',
      () {
        const expected = '''
Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.
''';

        final result = ValueCommand().description;

        expect(result.trim(), expected.trim());
      },
    );

    test(
      '''--${ValueCommand.inputOption}=<empty_trace_file>'''
      ''' | fails when trace file is empty''',
      () async {
        final emptyTraceFilePath = p.joinAll([
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'empty.lcov.info',
        ]);

        Future<void> action() => cmdRunner.run([
              'value',
              '--${ValueCommand.inputOption}',
              emptyTraceFilePath,
            ]);
        expect(
          action,
          throwsA(
            isA<CoverdeValueEmptyTraceFileFailure>().having(
              (e) => e.traceFilePath,
              'traceFilePath',
              p.absolute(emptyTraceFilePath),
            ),
          ),
        );
      },
    );

    test(
      '''--${ValueCommand.fileCoverageLogLevelFlag}=${FileCoverageLogLevel.none.identifier}''',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'partially_covered_proj',
        ]);
        final projectDir = Directory(projectPath);

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'value',
              '--${ValueCommand.fileCoverageLogLevelFlag}',
              FileCoverageLogLevel.none.identifier,
            ]);
          },
          getCurrentDirectory: () => Directory(projectPath),
        );

        final messages = [
          wrapWith('GLOBAL:', [blue, styleBold]),
          wrapWith('56.25% - 9/16', [blue, styleBold]),
        ];
        verifyInOrder([
          for (final message in messages) () => logger.info(message),
        ]);
      },
    );

    test(
      '''--${ValueCommand.fileCoverageLogLevelFlag}=${FileCoverageLogLevel.overview.identifier}''',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'partially_covered_proj',
        ]);
        final projectDir = Directory(projectPath);

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'value',
              '--${ValueCommand.fileCoverageLogLevelFlag}',
              FileCoverageLogLevel.overview.identifier,
            ]);
          },
          getCurrentDirectory: () => Directory(projectPath),
        );

        final messages = [
          () {
            final filePath = p.join('lib', 'source_01.dart');
            final fileOverview = wrapWith('(56.25% - 9/16)', [lightRed]);
            return '$filePath $fileOverview';
          }(),
          '',
          wrapWith('GLOBAL:', [blue, styleBold]),
          wrapWith('56.25% - 9/16', [blue, styleBold]),
        ];
        verifyInOrder([
          for (final message in messages) () => logger.info(message),
        ]);
      },
    );

    test(
      '''--${ValueCommand.fileCoverageLogLevelFlag}=${FileCoverageLogLevel.lineNumbers.identifier}''',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'partially_covered_proj',
        ]);
        final projectDir = Directory(projectPath);

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'value',
              '--${ValueCommand.fileCoverageLogLevelFlag}',
              FileCoverageLogLevel.lineNumbers.identifier,
            ]);
          },
          getCurrentDirectory: () => Directory(projectPath),
        );

        final messages = [
          () {
            final filePath = p.join('lib', 'source_01.dart');
            final fileOverview = wrapWith('(56.25% - 9/16)', [lightRed]);
            return '$filePath $fileOverview';
          }(),
          () {
            final message = wrapWith(
              'UNCOVERED: 7, 8, 17, 22, 23, 24, 26',
              [red, styleBold],
            );
            return '└ $message';
          }(),
          '',
          wrapWith('GLOBAL:', [blue, styleBold]),
          wrapWith('56.25% - 9/16', [blue, styleBold]),
        ];
        verifyInOrder([
          for (final message in messages) () => logger.info(message),
        ]);
      },
    );

    test(
      '''--${ValueCommand.fileCoverageLogLevelFlag}=${FileCoverageLogLevel.lineContent.identifier}''',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'value',
          'fixtures',
          'partially_covered_proj',
        ]);
        final projectDir = Directory(projectPath);

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'value',
              '--${ValueCommand.fileCoverageLogLevelFlag}',
              FileCoverageLogLevel.lineContent.identifier,
            ]);
          },
          getCurrentDirectory: () => Directory(projectPath),
        );

        const lineNumberColumnWidth = 2;
        String expectLine({
          required String marker,
          required int lineNumber,
          required String content,
          List<AnsiCode> styles = const [],
        }) {
          return [
            '├ ',
            wrapWith(marker, styles),
            ' ',
            wrapWith(
              '$lineNumber'.padLeft(lineNumberColumnWidth),
              styles,
            ),
            ' | ',
            wrapWith(content, styles),
          ].join();
        }

        final messages = [
          () {
            final filePath = p.join('lib', 'source_01.dart');
            final fileOverview = wrapWith('(56.25% - 9/16)', [lightRed]);
            return '$filePath $fileOverview';
          }(),
          expectLine(marker: ' ', lineNumber: 5, content: '}'),
          expectLine(marker: ' ', lineNumber: 6, content: ''),
          expectLine(
            marker: 'U',
            lineNumber: 7,
            content: 'num subtract(num a, num b) {',
            styles: const [red, styleBold],
          ),
          expectLine(
            marker: 'U',
            lineNumber: 8,
            content: '  return a - b;',
            styles: const [red, styleBold],
          ),
          expectLine(marker: ' ', lineNumber: 9, content: '}'),
          expectLine(marker: ' ', lineNumber: 10, content: ''),
          '├   •• | •••',
          expectLine(
            marker: 'C',
            lineNumber: 15,
            content: 'num divide(num a, num b) {',
            styles: const [green, styleBold],
          ),
          expectLine(
            marker: 'C',
            lineNumber: 16,
            content: '  if (b == 0) {',
            styles: const [green, styleBold],
          ),
          expectLine(
            marker: 'U',
            lineNumber: 17,
            content: "    throw Exception('Division by zero');",
            styles: const [red, styleBold],
          ),
          expectLine(marker: ' ', lineNumber: 18, content: '  }'),
          expectLine(
            marker: 'C',
            lineNumber: 19,
            content: '  return a / b;',
            styles: const [green, styleBold],
          ),
          expectLine(marker: ' ', lineNumber: 20, content: '}'),
          expectLine(marker: ' ', lineNumber: 21, content: ''),
          expectLine(
            marker: 'U',
            lineNumber: 22,
            content: 'num modulo(num a, num b) {',
            styles: const [red, styleBold],
          ),
          expectLine(
            marker: 'U',
            lineNumber: 23,
            content: '  if (b == 0) {',
            styles: const [red, styleBold],
          ),
          expectLine(
            marker: 'U',
            lineNumber: 24,
            content: "    throw Exception('Division by zero');",
            styles: const [red, styleBold],
          ),
          expectLine(marker: ' ', lineNumber: 25, content: '  }'),
          expectLine(
            marker: 'U',
            lineNumber: 26,
            content: '  return a % b;',
            styles: const [red, styleBold],
          ),
          expectLine(marker: ' ', lineNumber: 27, content: '}'),
          expectLine(marker: ' ', lineNumber: 28, content: ''),
          '',
          '',
          wrapWith('GLOBAL:', [blue, styleBold]),
          wrapWith('56.25% - 9/16', [blue, styleBold]),
        ];
        verifyInOrder([
          for (final message in messages) () => logger.info(message),
        ]);
      },
    );

    test(
      '--${ValueCommand.fileCoverageLogLevelFlag}=<invalid> '
      '| fails when --${ValueCommand.fileCoverageLogLevelFlag} is invalid',
      () async {
        const invalidLogLevel = 'invalid-log-level';
        final directory = Directory.systemTemp.createTempSync();
        final traceFilePath = p.join(directory.path, 'trace.lcov.info');
        File(traceFilePath).createSync(recursive: true);
        addTearDown(() => directory.deleteSync(recursive: true));

        Future<void> action() => cmdRunner.run([
              'value',
              '--${ValueCommand.inputOption}',
              traceFilePath,
              '--${ValueCommand.fileCoverageLogLevelFlag}',
              invalidLogLevel,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                '"invalid-log-level" is not an allowed value '
                'for option "--file-coverage-log-level"',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ValueCommand.inputOption} <absent_trace_file_path>',
      () async {
        final directory = Directory.systemTemp.createTempSync();
        final absentFilePath = p.join(directory.path, 'absent.lcov.info');
        final absentFile = File(absentFilePath);
        expect(absentFile.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              'value',
              '--${ValueCommand.inputOption}',
              absentFilePath,
            ]);

        expect(
          action,
          throwsA(isA<CoverdeValueTraceFileNotFoundFailure>()),
        );
        directory.deleteSync(recursive: true);
      },
    );

    test(
      '--${ValueCommand.inputOption}=<trace_file> '
      '''--${ValueCommand.fileCoverageLogLevelFlag}=${FileCoverageLogLevel.lineContent.identifier} '''
      '| throws $CoverdeValueFileReadFailure '
      'when source file read fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-value-test-');
        addTearDown(() => directory.delete(recursive: true));
        final traceFilePath = p.join(directory.path, 'lcov.info');
        final sourceFilePath = p.join(directory.path, 'test.dart');
        final traceFile = File(traceFilePath)
          ..createSync()
          ..writeAsStringSync('''
SF:$sourceFilePath
DA:1,0
LF:1
LH:0
end_of_record
''');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'value',
                  '--${ValueCommand.inputOption}',
                  traceFilePath,
                  '--${ValueCommand.fileCoverageLogLevelFlag}',
                  FileCoverageLogLevel.lineContent.identifier,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeValueFileReadFailure>(),
              ),
            );
          },
          createFile: (path) {
            if (p.equals(path, traceFilePath)) {
              return traceFile;
            }
            return _ValueTestFile(path: path);
          },
        );
      },
    );
  });
}

final class _ValueTestFile extends Fake implements File {
  _ValueTestFile({
    required this.path,
  });

  @override
  final String path;

  @override
  File get absolute {
    return File(p.absolute(path));
  }

  @override
  List<String> readAsLinesSync({
    Encoding encoding = utf8,
  }) {
    throw FileSystemException('Fake file read error', path);
  }
}
