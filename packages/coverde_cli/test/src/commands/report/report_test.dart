import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:csslib/parser.dart' as css;
import 'package:html/dom.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

enum _Project {
  fakeProject1('fake_project_1'),
  fakeProject2('fake_project_2'),
  ;

  const _Project(this.path);

  final String path;
}

extension _ExtendedProj on _Project {
  Iterable<String> get relFilePaths {
    switch (this) {
      case _Project.fakeProject1:
        return [
          'dir_1/file_1.dart.html',
          'dir_1/file_2.dart.html',
          'dir_1/index.html',
          'dir_2/dir_1/file_1.dart.html',
          'dir_2/dir_1/file_2.dart.html',
          'dir_2/dir_1/index.html',
          'index.html',
          'report_style.css',
          'sort_alpha.png',
          'sort_numeric.png',
        ];
      case _Project.fakeProject2:
        return [
          'models/index.html',
          'models/model_1.dart.html',
          'models/model_2.dart.html',
          'models/model_3.dart.html',
          'exception.dart.html',
          'fake_project_2.dart.html',
          'index.html',
        ];
    }
  }
}

extension on String {
  String fixturePath({
    required _Project proj,
  }) =>
      path.joinAll([
        'test',
        'src',
        'commands',
        'report',
        'fixtures',
        proj.path,
        this,
      ]);
}

class MockProcessManager extends Mock implements ProcessManager {}

void main() {
  group('coverde report', () {
    late CommandRunner<void> cmdRunner;
    late MockStdout out;
    late ReportCommand reportCmd;

    setUp(() {
      cmdRunner = CommandRunner<void>('test', 'A tester command runner');
      out = MockStdout();
      reportCmd = ReportCommand(out: out);
      cmdRunner.addCommand(reportCmd);
    });

    tearDown(() {
      verifyNoMoreInteractions(out);
    });

    test(
        '''--${ReportCommand.inputOption}=<empty_trace_file> '''
        '''| fails when trace file is empty''', () async {
      final emptyTraceFilePath = path.joinAll([
        'test',
        'src',
        'commands',
        'report',
        'fixtures',
        'empty.lcov.info',
      ]);
      final emptyTraceFile = File(emptyTraceFilePath);
      expect(emptyTraceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            reportCmd.name,
            '--${ReportCommand.inputOption}',
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
    });
  });

  test(
    '''

A trace file report generator command should be instantiable
''',
    () {
      // ACT
      final result = ReportCommand();

      // ASSERT
      expect(result, isNotNull);
    },
  );

  group(
    '''

GIVEN a trace file report generator command''',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late MockProcessManager processManager;
      late ReportCommand reportCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          processManager = MockProcessManager();
          reportCmd = ReportCommand(
            out: out,
            processManager: processManager,
          );
          cmdRunner.addCommand(reportCmd);
        },
      );

      test(
        '''

WHEN its description is requested
THEN a proper abstract should be returned
''',
        () {
          // ARRANGE
          const expected = '''
Generate the coverage report from a trace file.

Generate the coverage report inside REPORT_DIR from the TRACE_FILE trace file.
''';

          // ACT
          final result = reportCmd.description;

          // ASSERT
          expect(result.trim(), expected.trim());
        },
      );

      {
        for (final proj in _Project.values) {
          test(
            '''

AND an existing trace file <${proj.name}>
WHEN the command is invoked
THEN a coverage report should be launched
├─ BY generating an HTML report
├─ AND launching it in a browser
''',
            () async {
              // ARRANGE
              final traceFilePath = path.joinAll([
                'coverage',
                // cspell: disable-next-line
                if (Platform.isWindows) 'windows' else 'posix',
                'lcov.info',
              ]).fixturePath(proj: proj);
              final traceFileFile = File(traceFilePath);
              const resultDirName = 'result';
              const expectedDirName = 'expected';
              final reportDirPath = resultDirName.fixturePath(proj: proj);
              final reportDir = Directory(reportDirPath);
              const listEquality = ListEquality<int>();
              when(
                () => processManager.run(
                  any(),
                  runInShell: any(named: 'runInShell'),
                ),
              ).thenAnswer(
                (_) async => Future.value(
                  ProcessResult(0, 0, '', ''),
                ),
              );

              expect(traceFileFile.existsSync(), isTrue);

              // ACT
              await cmdRunner.run([
                reportCmd.name,
                '--${ReportCommand.inputOption}',
                traceFilePath,
                '--${ReportCommand.outputOption}',
                reportDirPath,
                '--${ReportCommand.launchFlag}',
              ]);

              // ASSERT
              expect(reportDir.existsSync(), isTrue);
              for (final relFilePath in proj.relFilePaths) {
                final resultFile = File(
                  path
                      .join(
                        resultDirName,
                        relFilePath,
                      )
                      .fixturePath(proj: proj),
                );
                final expectedFile = File(
                  path
                      .join(
                        expectedDirName,
                        relFilePath,
                      )
                      .fixturePath(proj: proj),
                );
                if (relFilePath.endsWith('png')) {
                  final result = resultFile.readAsBytesSync();
                  final expected = expectedFile.readAsBytesSync();
                  final haveSameContent = listEquality.equals(result, expected);
                  expect(
                    haveSameContent,
                    isTrue,
                    reason: 'Non-matching (bytes) file <$relFilePath>',
                  );
                } else {
                  final result = resultFile.readAsStringSync();
                  final expected = expectedFile.readAsStringSync();
                  const splitter = LineSplitter();
                  if (relFilePath.endsWith('html')) {
                    const lastTraceFileModificationDateSelector =
                        '.lastTraceFileModificationDate';
                    final resultHtml = Document.html(result);
                    final expectedHtml = Document.html(expected);
                    resultHtml
                        .querySelector(lastTraceFileModificationDateSelector)
                        ?.remove();
                    expectedHtml
                        .querySelector(lastTraceFileModificationDateSelector)
                        ?.remove();
                    expect(
                      splitter
                          .convert(resultHtml.outerHtml)
                          .map((line) => line.trim()),
                      splitter
                          .convert(expectedHtml.outerHtml)
                          .map((line) => line.trim()),
                      reason: 'Error: Non-matching (html) file <$relFilePath>',
                    );
                  } else if (relFilePath.endsWith('css')) {
                    final resultCss = css.parse(result);
                    final expectedCss = css.parse(expected);
                    expect(
                      splitter.convert(resultCss.toDebugString()),
                      splitter.convert(expectedCss.toDebugString()),
                      reason: 'Error: Non-matching (css) file <$relFilePath>',
                    );
                  } else {
                    expect(
                      splitter.convert(result),
                      splitter.convert(expected),
                      reason: '''
Error: Non-matching (plain text) file <$relFilePath>''',
                    );
                  }
                }
              }
              verify(
                () => processManager.run(
                  any(
                    that: containsAllInOrder(
                      <Matcher>[
                        equals(launchCommands[Platform.operatingSystem]),
                        contains(path.join(reportDirPath, 'index.html')),
                      ],
                    ),
                  ),
                  runInShell: true,
                ),
              ).called(1);
            },
          );
        }
      }

      test(
        '''

AND a non-existing trace file
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          final absentFilePath = path.joinAll([
            'test',
            'src',
            'commands',
            'report',
            'fixtures',
            'absent.lcov.info',
          ]);
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                reportCmd.name,
                '--${ReportCommand.inputOption}',
                absentFilePath,
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '''

AND an invalid medium threshold
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const invalidMediumThreshold = 'medium';

          // ACT
          Future<void> action() => cmdRunner.run([
                reportCmd.name,
                '--${ReportCommand.mediumOption}',
                invalidMediumThreshold,
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '''

AND an invalid high threshold
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const invalidHighThreshold = 'high';

          // ACT
          Future<void> action() => cmdRunner.run([
                reportCmd.name,
                '--${ReportCommand.highOption}',
                invalidHighThreshold,
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
