import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:io/ansi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../helpers/test_files.dart';
import '../../../utils/mocks.dart';

void main() {
  group(
    'coverde value',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late ValueCommand valueCmd;

      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          valueCmd = ValueCommand(out: out);
          cmdRunner.addCommand(valueCmd);
        },
      );

      tearDown(
        () {
          verifyNoMoreInteractions(out);
        },
      );

      test(
        '| description',
        () {
          // ARRANGE
          const expected = '''
Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.
''';

          // ACT
          final result = valueCmd.description;

          // ASSERT
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
                valueCmd.name,
                '--${ValueCommand.inputOption}',
                emptyTraceFilePath,
              ]);
          expect(
            action,
            throwsA(
              isA<CovFileFormatException>().having(
                (e) => e.message,
                'message',
                'No coverage data found in the trace file.',
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
                valueCmd.name,
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
            for (final message in messages) () => out.writeln(message),
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
                valueCmd.name,
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
            for (final message in messages) () => out.writeln(message),
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
                valueCmd.name,
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
            for (final message in messages) () => out.writeln(message),
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
                valueCmd.name,
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
            for (final message in messages) () => out.writeln(message),
          ]);
        },
      );

      test(
        '--${ValueCommand.inputOption} <absent_trace_file_path>',
        () async {
          // ARRANGE
          final directory = Directory.systemTemp.createTempSync();
          final absentFilePath = p.join(directory.path, 'absent.lcov.info');
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                valueCmd.name,
                '--${ValueCommand.inputOption}',
                absentFilePath,
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
          directory.deleteSync(recursive: true);
        },
      );
    },
  );
}
