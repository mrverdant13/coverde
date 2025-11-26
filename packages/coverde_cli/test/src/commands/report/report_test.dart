import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/report/report.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:csslib/parser.dart' as css;
import 'package:html/dom.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
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

  String get traceFilePath => p.joinAll([
        'test',
        'src',
        'commands',
        'report',
        'fixtures',
        path,
        'coverage',
        if (Platform.isWindows) 'windows' else 'posix',
        'lcov.info',
      ]);
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
      p.joinAll([
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
    late Logger logger;
    late MockProcessManager processManager;
    late ReportCommand reportCmd;

    setUp(() {
      cmdRunner = CommandRunner<void>('test', 'A tester command runner');
      logger = MockLogger();
      processManager = MockProcessManager();
      reportCmd = ReportCommand(
        logger: logger,
        processManager: processManager,
      );
      cmdRunner.addCommand(reportCmd);
    });

    tearDown(() {
      verifyNoMoreInteractions(logger);
    });

    test(
        '''--${ReportCommand.inputOption}=<empty_trace_file> '''
        '''| fails when trace file is empty''', () async {
      final emptyTraceFilePath = p.joinAll([
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

    test(
      '| can be instantiated',
      () {
        final result = ReportCommand();

        expect(result, isNotNull);
      },
    );

    test(
      '| description',
      () {
        const expected = '''
Generate the coverage report from a trace file.

Generate the coverage report inside REPORT_DIR from the TRACE_FILE trace file.
''';

        final result = reportCmd.description;

        expect(result.trim(), expected.trim());
      },
    );

    {
      for (final proj in _Project.values) {
        test(
          '--${ReportCommand.inputOption}=<trace_file> '
          '--${ReportCommand.outputOption}=<report_dir> '
          '--${ReportCommand.launchFlag} '
          '| generates HTML report and launches browser for ${proj.name}',
          () async {
            final traceFilePath = p.joinAll([
              'coverage',
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

            await cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.outputOption}',
              reportDirPath,
              '--${ReportCommand.launchFlag}',
            ]);

            expect(reportDir.existsSync(), isTrue);
            for (final relFilePath in proj.relFilePaths) {
              final resultFile = File(
                p
                    .join(
                      resultDirName,
                      relFilePath,
                    )
                    .fixturePath(proj: proj),
              );
              final expectedFile = File(
                p
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
                      contains(p.join(reportDirPath, 'index.html')),
                    ],
                  ),
                ),
                runInShell: true,
              ),
            ).called(1);
            verify(
              () => logger.info(any()),
            ).called(2);
          },
        );
      }
    }

    test(
      '--${ReportCommand.inputOption}=<absent_file> '
      '| fails when trace file does not exist',
      () async {
        final absentFilePath = p.joinAll([
          'test',
          'src',
          'commands',
          'report',
          'fixtures',
          'absent.lcov.info',
        ]);
        final absentFile = File(absentFilePath);
        expect(absentFile.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              absentFilePath,
            ]);

        expect(action, throwsA(isA<UsageException>()));
      },
    );

    test(
      '--${ReportCommand.mediumOption}=<invalid> '
      '| fails when medium threshold is invalid',
      () async {
        const invalidMediumThreshold = 'invalid';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.mediumOption}',
              invalidMediumThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains('Invalid medium threshold.'),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.mediumOption}=<negative> '
      '| fails when medium threshold is negative',
      () async {
        const negativeMediumThreshold = '-1';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.mediumOption}',
              negativeMediumThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'Medium threshold must be between 0 and 100 '
                '(got -1.0).',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.mediumOption}=<over_100> '
      '| fails when medium threshold exceeds 100',
      () async {
        const over100MediumThreshold = '101';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.mediumOption}',
              over100MediumThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'Medium threshold must be between 0 and 100 '
                '(got 101.0).',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.highOption}=<invalid> '
      '| fails when high threshold is invalid',
      () async {
        const invalidHighThreshold = 'invalid';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.highOption}',
              invalidHighThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains('Invalid high threshold.'),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.highOption}=<negative> '
      '| fails when high threshold is negative',
      () async {
        const negativeHighThreshold = '-1';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.highOption}',
              negativeHighThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'High threshold must be between 0 and 100 '
                '(got -1.0).',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.highOption}=<over_100> '
      '| fails when high threshold exceeds 100',
      () async {
        const over100HighThreshold = '101';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.highOption}',
              over100HighThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'High threshold must be between 0 and 100 '
                '(got 101.0).',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.mediumOption}=<value> '
      '--${ReportCommand.highOption}=<lower_value> '
      '| fails when medium threshold is greater than high threshold',
      () async {
        const mediumThreshold = '75';
        const highThreshold = '50'; // Lower than medium
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.mediumOption}',
              mediumThreshold,
              '--${ReportCommand.highOption}',
              highThreshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'Medium threshold (75.0) '
                'must be less than high threshold (50.0).',
              ),
            ),
          ),
        );
      },
    );

    test(
      '--${ReportCommand.mediumOption}=<value> '
      '--${ReportCommand.highOption}=<same_value> '
      '| fails when medium threshold equals high threshold',
      () async {
        const threshold = '75';
        final traceFilePath = _Project.fakeProject1.traceFilePath;
        final traceFile = File(traceFilePath);
        expect(traceFile.existsSync(), isTrue);

        Future<void> action() => cmdRunner.run([
              reportCmd.name,
              '--${ReportCommand.inputOption}',
              traceFilePath,
              '--${ReportCommand.mediumOption}',
              threshold,
              '--${ReportCommand.highOption}',
              threshold,
            ]);

        expect(
          action,
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains(
                'Medium threshold (75.0) '
                'must be less than high threshold (75.0).',
              ),
            ),
          ),
        );
      },
    );
  });
}
