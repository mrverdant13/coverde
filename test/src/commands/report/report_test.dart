import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:html/dom.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a tracefile report generator command''',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late ReportCommand reportCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          reportCmd = ReportCommand(out: out);
          cmdRunner.addCommand(reportCmd);
        },
      );

      test(
        '''

AND an existing tracefile
WHEN the command is invoqued
THEN an HTML coverage report should be generated
''',
        () async {
          // ARRANGE
          const tracefileFilePath = 'test/fixtures/report/lcov.info';
          final tracefileFile = File(tracefileFilePath);
          const fixturesBasePath = 'test/fixtures/report';
          const resultDirName = 'result';
          const expectedDirName = 'expected';
          final reportDirPath = path.join(fixturesBasePath, resultDirName);
          final reportDir = Directory(reportDirPath);
          final relFilePaths = [
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
          const listEquality = ListEquality<int>();

          expect(tracefileFile.existsSync(), isTrue);

          // ACT
          await cmdRunner.run([
            reportCmd.name,
            '--${ReportCommand.inputTracefileOption}',
            tracefileFilePath,
            '--${ReportCommand.outputReportDirOption}',
            reportDirPath,
          ]);

          // ASSERT
          expect(reportDir.existsSync(), isTrue);
          for (final relFilePath in relFilePaths) {
            final resultFile = File(
              path.join(
                fixturesBasePath,
                resultDirName,
                relFilePath,
              ),
            );
            final expectedFile = File(
              path.join(
                fixturesBasePath,
                expectedDirName,
                relFilePath,
              ),
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
                  reason: 'Non-matching (html) file <$relFilePath>',
                );
              } else {
                expect(
                  result,
                  expected,
                  reason: 'Non-matching (plain text) file <$relFilePath>',
                );
              }
            }
          }
        },
      );

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
                '--${ReportCommand.inputTracefileOption}',
                absentFilePath,
              ]);

          // ASSERT
          expect(action, throwsA(isA<StateError>()));
        },
      );
    },
  );
}
