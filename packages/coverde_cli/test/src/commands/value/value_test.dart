import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/value/value.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:io/ansi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

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

          final messages = [
            () {
              final filePath = p.join('lib', 'source_01.dart');
              final fileOverview = wrapWith('(56.25% - 9/16)', [lightRed]);
              return '$filePath $fileOverview';
            }(),
            '├  5 | }',
            '├  6 | ',
            [
              '├  ',
              wrapWith(
                '7',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                'num subtract(num a, num b) {',
                [red, styleBold],
              ),
            ].join(),
            [
              '├  ',
              wrapWith(
                '8',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                '  return a - b;',
                [red, styleBold],
              ),
            ].join(),
            '├  9 | }',
            '├ 10 | ',
            [
              '├ ',
              wrapWith(
                '15',
                [green, styleBold],
              ),
              ' | ',
              wrapWith(
                'num divide(num a, num b) {',
                [green, styleBold],
              ),
            ].join(),
            [
              '├ ',
              wrapWith(
                '16',
                [green, styleBold],
              ),
              ' | ',
              wrapWith(
                '  if (b == 0) {',
                [green, styleBold],
              ),
            ].join(),
            [
              '├ ',
              wrapWith(
                '17',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                "    throw Exception('Division by zero');",
                [red, styleBold],
              ),
            ].join(),
            '├ 18 |   }',
            [
              '├ ',
              wrapWith(
                '19',
                [green, styleBold],
              ),
              ' | ',
              wrapWith(
                '  return a / b;',
                [green, styleBold],
              ),
            ].join(),
            '├ 20 | }',
            '├ 21 | ',
            [
              '├ ',
              wrapWith(
                '22',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                'num modulo(num a, num b) {',
                [red, styleBold],
              ),
            ].join(),
            [
              '├ ',
              wrapWith(
                '23',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                '  if (b == 0) {',
                [red, styleBold],
              ),
            ].join(),
            [
              '├ ',
              wrapWith(
                '24',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                "    throw Exception('Division by zero');",
                [red, styleBold],
              ),
            ].join(),
            '├ 25 |   }',
            [
              '├ ',
              wrapWith(
                '26',
                [red, styleBold],
              ),
              ' | ',
              wrapWith(
                '  return a % b;',
                [red, styleBold],
              ),
            ].join(),
            '├ 27 | }',
            '├ 28 | ',
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
