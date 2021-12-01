import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:csslib/parser.dart' as css;
import 'package:html/dom.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

enum _Project {
  // ignore: constant_identifier_names
  fake_project_1,
  // ignore: constant_identifier_names
  fake_project_2,
}

extension _ExtendedProj on _Project {
  String get name => toString().split('.').last;
  Iterable<String> get relFilePaths {
    switch (this) {
      case _Project.fake_project_1:
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
      case _Project.fake_project_2:
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

extension _FixturedString on String {
  String fixturePath({
    required _Project proj,
  }) =>
      path.join(
        'test/src/commands/report/fixtures',
        proj.name,
        this,
      );
}

class MockProcessManager extends Mock implements ProcessManager {}

class FakeProcessResult extends Mock implements ProcessResult {}

void main() {
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

GIVEN a tracefile report generator command''',
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
Generate the coverage report from a tracefile.

Genrate the coverage report inside REPORT_DIR from the TRACEFILE tracefile.
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

AND an existing tracefile <${proj.name}>
WHEN the command is invoqued
THEN a coverage report should be launched
├─ BY generating an HTML report
├─ AND launching it in a browser 
''',
            () async {
              // ARRANGE
              final tracefileFilePath = 'lcov.info'.fixturePath(proj: proj);
              final tracefileFile = File(tracefileFilePath);
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
                  FakeProcessResult(),
                ),
              );

              expect(tracefileFile.existsSync(), isTrue);

              // ACT
              await cmdRunner.run([
                reportCmd.name,
                '--${ReportCommand.inputOption}',
                tracefileFilePath,
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
                  if (relFilePath.endsWith('html')) {
                    const lastTracefileModificationDateSelector =
                        '.lastTracefileModificationDate';
                    final resultHtml = Document.html(result);
                    final expectedHtml = Document.html(expected);
                    resultHtml
                        .querySelector(lastTracefileModificationDateSelector)
                        ?.remove();
                    expectedHtml
                        .querySelector(lastTracefileModificationDateSelector)
                        ?.remove();
                    expect(
                      resultHtml.outerHtml,
                      expectedHtml.outerHtml,
                      reason: 'Error: Non-matching (html) file <$relFilePath>',
                    );
                  } else if (relFilePath.endsWith('css')) {
                    const splitter = LineSplitter();
                    final resultCss = css.parse(result);
                    final expectedCss = css.parse(expected);
                    expect(
                      splitter.convert(resultCss.toDebugString()).join('\n'),
                      splitter.convert(expectedCss.toDebugString()).join('\n'),
                      reason: 'Error: Non-matching (css) file <$relFilePath>',
                    );
                  } else {
                    expect(
                      result,
                      expected,
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

AND a non-existing tracefile
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const absentFilePath = 'test/fixtures/report/absent.lcov.info';
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
WHEN the command is invoqued
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
WHEN the command is invoqued
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
