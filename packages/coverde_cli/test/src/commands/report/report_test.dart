import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:csslib/parser.dart' as css;
import 'package:html/dom.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

class _MockProcessManager extends Mock implements ProcessManager {}

final class _MockLogger extends Mock implements Logger {}

final class _MockPackageVersionManager extends Mock
    implements PackageVersionManager {}

final class _FakeCoverdeCommandRunner extends CoverdeCommandRunner {
  _FakeCoverdeCommandRunner({
    required super.logger,
    required super.packageVersionManager,
    required super.processManager,
  });

  @override
  Future<void> run(Iterable<String> args) {
    return super.run([
      ...args,
      '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}''',
    ]);
  }
}

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

void main() {
  group('coverde report', () {
    late Logger logger;
    late ProcessManager processManager;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      processManager = _MockProcessManager();
      packageVersionManager = _MockPackageVersionManager();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        processManager: processManager,
        packageVersionManager: packageVersionManager,
      );
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
            'report',
            '--${ReportCommand.inputOption}',
            emptyTraceFilePath,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportEmptyTraceFileFailure>().having(
            (e) => e.traceFilePath,
            'traceFilePath',
            p.absolute(emptyTraceFilePath),
          ),
        ),
      );
    });

    test('| can be instantiated', () {
      final result = ReportCommand();

      expect(result, isNotNull);
    });

    test('| description', () {
      const expected = '''
Generate the coverage report from a trace file.

Generate the coverage report inside REPORT_DIR from the TRACE_FILE trace file.
''';

      final result = ReportCommand().description;

      expect(result.trim(), expected.trim());
    });

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
            'report',
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
                    equals(launchCommands[operatingSystemIdentifier]),
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
        });
      }
    }

    test(
        '--${ReportCommand.inputOption}=<trace_file> '
        '--${ReportCommand.outputOption}=<report_dir> '
        '--${ReportCommand.launchFlag} '
        '| generates HTML report and warns '
        'when launch is not supported for platform', () async {
      // Set to an unsupported platform
      debugOperatingSystemIdentifier = 'android';
      addTearDown(() => debugOperatingSystemIdentifier = null);

      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFileFile = File(traceFilePath);
      const resultDirName = 'result';
      final reportDirPath =
          resultDirName.fixturePath(proj: _Project.fakeProject1);
      final reportDir = Directory(reportDirPath);

      expect(traceFileFile.existsSync(), isTrue);

      await cmdRunner.run([
        'report',
        '--${ReportCommand.inputOption}',
        traceFilePath,
        '--${ReportCommand.outputOption}',
        reportDirPath,
        '--${ReportCommand.launchFlag}',
      ]);

      // Report should still be generated
      expect(reportDir.existsSync(), isTrue);
      final reportIndexFile = File(
        p.join(reportDirPath, 'index.html'),
      );
      expect(reportIndexFile.existsSync(), isTrue);

      // Should log warning about unsupported platform
      verify(
        () => logger.warn(
          'Browser launch is not supported on android platform.',
        ),
      ).called(1);
      verify(
        () => logger.info(
          any(),
        ),
      ).called(2);
      verifyNever(
        () => processManager.run(
          any(),
          runInShell: any(named: 'runInShell'),
        ),
      );
    });

    test(
        '--${ReportCommand.inputOption}=<trace_file> '
        '--${ReportCommand.outputOption}=<report_dir> '
        '--${ReportCommand.launchFlag} '
        '| logs error when browser launch fails', () async {
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFileFile = File(traceFilePath);
      const resultDirName = 'result';
      final reportDirPath =
          resultDirName.fixturePath(proj: _Project.fakeProject1);
      final reportDir = Directory(reportDirPath);
      when(
        () => processManager.run(
          any(),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenThrow(Exception('Browser not found'));
      expect(traceFileFile.existsSync(), isTrue);

      await cmdRunner.run([
        'report',
        '--${ReportCommand.inputOption}',
        traceFilePath,
        '--${ReportCommand.outputOption}',
        reportDirPath,
        '--${ReportCommand.launchFlag}',
      ]);

      expect(reportDir.existsSync(), isTrue);
      final reportIndexFile = File(
        p.join(reportDirPath, 'index.html'),
      );
      expect(reportIndexFile.existsSync(), isTrue);
      verify(
        () => logger.info(any()),
      ).called(2);
      verify(
        () => logger.err(any(that: contains('Failed to launch browser'))),
      ).called(1);
    });

    test(
        '--${ReportCommand.inputOption}=<absent_file> '
        '| fails when trace file does not exist', () async {
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
            'report',
            '--${ReportCommand.inputOption}',
            absentFilePath,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportTraceFileNotFoundFailure>().having(
            (e) => e.traceFilePath,
            'traceFilePath',
            p.absolute(absentFilePath),
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.mediumOption}=<invalid> '
        '| fails when medium threshold is invalid', () async {
      const invalidMediumThreshold = 'invalid';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.mediumOption}',
            invalidMediumThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidMediumThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid medium threshold: `$invalidMediumThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.mediumOption}=<negative> '
        '| fails when medium threshold is negative', () async {
      const negativeMediumThreshold = '-1';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.mediumOption}',
            negativeMediumThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidMediumThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid medium threshold: `$negativeMediumThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.mediumOption}=<over_100> '
        '| fails when medium threshold exceeds 100', () async {
      const over100MediumThreshold = '101';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.mediumOption}',
            over100MediumThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidMediumThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid medium threshold: `$over100MediumThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.highOption}=<invalid> '
        '| fails when high threshold is invalid', () async {
      const invalidHighThreshold = 'invalid';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.highOption}',
            invalidHighThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidHighThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid high threshold: `$invalidHighThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.highOption}=<negative> '
        '| fails when high threshold is negative', () async {
      const negativeHighThreshold = '-1';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.highOption}',
            negativeHighThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidHighThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid high threshold: `$negativeHighThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.highOption}=<over_100> '
        '| fails when high threshold exceeds 100', () async {
      const over100HighThreshold = '101';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
            '--${ReportCommand.inputOption}',
            traceFilePath,
            '--${ReportCommand.highOption}',
            over100HighThreshold,
          ]);

      expect(
        action,
        throwsA(
          isA<CoverdeReportInvalidHighThresholdFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Invalid high threshold: `$over100HighThreshold`.\n'
                'It should be a positive number not greater than 100 '
                '[0.0, 100.0].',
          ),
        ),
      );
    });

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
            'report',
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
          isA<CoverdeReportInvalidThresholdRelationshipFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Medium threshold (75.0) must be less than '
                'high threshold (50.0).',
          ),
        ),
      );
    });

    test(
        '--${ReportCommand.mediumOption}=<value> '
        '--${ReportCommand.highOption}=<same_value> '
        '| fails when medium threshold equals high threshold', () async {
      const threshold = '75';
      final traceFilePath = _Project.fakeProject1.traceFilePath;
      final traceFile = File(traceFilePath);
      expect(traceFile.existsSync(), isTrue);

      Future<void> action() => cmdRunner.run([
            'report',
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
          isA<CoverdeReportInvalidThresholdRelationshipFailure>().having(
            (e) => e.invalidInputDescription,
            'invalidInputDescription',
            'Medium threshold (75.0) must be less than '
                'high threshold (75.0).',
          ),
        ),
      );
    });

    test(
        '| throws $CoverdeReportFileReadFailure '
        'when trace file read fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileReadFailure>().having(
                (e) => e.filePath,
                'filePath',
                traceFilePath,
              ),
            ),
          );
        },
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return _ReportTestFile(
              path: path,
              existsSync: () => true,
              openRead: ([start, end]) => Stream.value(
                utf8.encode('''
SF:test.dart
DA:1,0
LF:1
LH:0
end_of_record
'''),
              ),
              lastModifiedSync: () => throw FileSystemException(
                'Fake file read error',
                path,
              ),
            );
          }
          if (p.basename(path) == 'test.dart') {
            return _ReportTestFile(
              path: path,
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileCreateFailure '
        'when report CSS file create fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileCreateFailure>().having(
                (e) => e.filePath,
                'filePath',
                coverageStyleFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {
                throw FileSystemException(
                  'Fake file create error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileWriteFailure '
        'when report CSS file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                coverageStyleFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsBytesSync: (
                bytes, {
                mode = FileMode.write,
                flush = false,
              }) {
                throw FileSystemException(
                  'Fake file write error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileCreateFailure '
        'when report alphabetical sort icon file create fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);
      final coverageStyleFile = File(coverageStyleFilePath);
      final sortAlphaIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_alpha.png',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileCreateFailure>().having(
                (e) => e.filePath,
                'filePath',
                sortAlphaIconFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return coverageStyleFile;
          }
          if (p.basename(path) == 'sort_alpha.png') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {
                throw FileSystemException(
                  'Fake file create error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileWriteFailure '
        'when report alphabetical sort icon file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);
      final coverageStyleFile = File(coverageStyleFilePath);
      final sortAlphaIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_alpha.png',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                sortAlphaIconFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return coverageStyleFile;
          }
          if (p.basename(path) == 'sort_alpha.png') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsBytesSync: (
                bytes, {
                mode = FileMode.write,
                flush = false,
              }) {
                throw FileSystemException(
                  'Fake file write error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileCreateFailure '
        'when report numeric sort icon file create fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);
      final coverageStyleFile = File(coverageStyleFilePath);
      final sortAlphaIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_alpha.png',
      ]);
      final sortAlphaIconFile = File(sortAlphaIconFilePath);
      final sortNumericIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_numeric.png',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileCreateFailure>().having(
                (e) => e.filePath,
                'filePath',
                sortNumericIconFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return coverageStyleFile;
          }
          if (p.basename(path) == 'sort_alpha.png') {
            return sortAlphaIconFile;
          }
          if (p.basename(path) == 'sort_numeric.png') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {
                throw FileSystemException(
                  'Fake file create error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileWriteFailure '
        'when report numeric sort icon file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final coverageHtmlReportPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final coverageHtmlReportIndexPath = p.joinAll([
        coverageHtmlReportPath,
        'index.html',
      ]);
      final coverageHtmlReportIndexFile = File(coverageHtmlReportIndexPath);
      final sourceFileHtmlReportPath = p.joinAll([
        coverageHtmlReportPath,
        'some_source_file.dart.html',
      ]);
      final sourceFileHtmlReportFile = File(sourceFileHtmlReportPath);
      final coverageStyleFilePath = p.joinAll([
        coverageHtmlReportPath,
        'report_style.css',
      ]);
      final coverageStyleFile = File(coverageStyleFilePath);
      final sortAlphaIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_alpha.png',
      ]);
      final sortAlphaIconFile = File(sortAlphaIconFilePath);
      final sortNumericIconFilePath = p.joinAll([
        coverageHtmlReportPath,
        'sort_numeric.png',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                sortNumericIconFilePath,
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (p.basename(path) == 'index.html') {
            return coverageHtmlReportIndexFile;
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return sourceFileHtmlReportFile;
          }
          if (p.basename(path) == 'report_style.css') {
            return coverageStyleFile;
          }
          if (p.basename(path) == 'sort_alpha.png') {
            return sortAlphaIconFile;
          }
          if (p.basename(path) == 'sort_numeric.png') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsBytesSync: (
                bytes, {
                mode = FileMode.write,
                flush = false,
              }) {
                throw FileSystemException(
                  'Fake file write error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileReadFailure '
        'when source file read fails during report generation', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileReadFailure>().having(
                (e) => e.filePath,
                'filePath',
                endsWith('some_source_file.dart'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return _ReportTestFile(
              path: path,
              existsSync: () => true,
              readAsLinesSync: (encoding) => throw FileSystemException(
                'Fake file read error',
                path,
              ),
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportTraceFileReadFailure '
        'when trace file read fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportTraceFileReadFailure>().having(
                (e) => e.traceFilePath,
                'traceFilePath',
                p.absolute(traceFilePath),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return _ReportTestFile(
              path: path,
              existsSync: () => true,
              openRead: ([start, end]) => Stream<List<int>>.error(
                FileSystemException('Fake file read error', path),
              ),
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileCreateFailure '
        'when directory index.html file create fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final outputDirPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final rootIndexHtmlFilePath = p.joinAll([
        outputDirPath,
        'index.html',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
                '--${ReportCommand.outputOption}',
                outputDirPath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileCreateFailure>().having(
                (e) => e.filePath,
                'filePath',
                endsWith('index.html'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (path == rootIndexHtmlFilePath) {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {
                throw FileSystemException(
                  'Fake directory index create error',
                  path,
                );
              },
            );
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsStringSync: (
                contents, {
                mode = FileMode.write,
                encoding = utf8,
                flush = false,
              }) {},
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileWriteFailure '
        'when directory index.html file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');
      final outputDirPath = p.joinAll([
        directory.path,
        'coverage',
        'html',
      ]);
      final rootIndexHtmlFilePath = p.joinAll([
        outputDirPath,
        'index.html',
      ]);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
                '--${ReportCommand.outputOption}',
                outputDirPath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                endsWith('index.html'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          if (path == rootIndexHtmlFilePath) {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsStringSync: (
                contents, {
                mode = FileMode.write,
                encoding = utf8,
                flush = false,
              }) {
                throw FileSystemException(
                  'Fake directory index write error',
                  path,
                );
              },
            );
          }
          if (p.basename(path) == 'some_source_file.dart.html') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsStringSync: (
                contents, {
                mode = FileMode.write,
                encoding = utf8,
                flush = false,
              }) {},
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileCreateFailure '
        'when source file HTML report file create fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileCreateFailure>().having(
                (e) => e.filePath,
                'filePath',
                endsWith('some_source_file.dart.html'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          // Directory index.html - should succeed
          if (p.basename(path) == 'index.html' &&
              path.contains('coverage/html') &&
              !path.contains('lib')) {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
            );
          }
          // Source file HTML report - should fail on create
          if (p.basename(path) == 'some_source_file.dart.html') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {
                throw FileSystemException(
                  'Fake source HTML create error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });

    test(
        '| throws $CoverdeReportFileWriteFailure '
        'when source file HTML report file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-report-test-');
      addTearDown(() => directory.delete(recursive: true));
      final traceFilePath = p.join(directory.path, 'coverage', 'lcov.info');
      final traceFile = File(traceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
SF:lib/some_source_file.dart
DA:1,0
LF:1
LH:0
end_of_record
''');
      final sourceFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_source_file.dart',
      ]);
      final sourceFile = File(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'report',
                '--${ReportCommand.inputOption}',
                traceFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeReportFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                endsWith('some_source_file.dart.html'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => directory,
        createFile: (path) {
          if (p.basename(path) == 'lcov.info') {
            return traceFile;
          }
          if (p.basename(path) == 'some_source_file.dart') {
            return sourceFile;
          }
          // Directory index.html - should succeed
          if (p.basename(path) == 'index.html' &&
              path.contains('coverage/html') &&
              !path.contains('lib')) {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
            );
          }
          // Source file HTML report - should fail on write
          if (p.basename(path) == 'some_source_file.dart.html') {
            return _ReportTestFile(
              path: path,
              createSync: ({recursive = false, exclusive = false}) {},
              writeAsStringSync: (
                contents, {
                mode = FileMode.write,
                encoding = utf8,
                flush = false,
              }) {
                throw FileSystemException(
                  'Fake source HTML write error',
                  path,
                );
              },
            );
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });
  });

  group('launchCommands', () {
    test('| contains commands for all supported platforms', () {
      expect(launchCommands['linux'], equals('xdg-open'));
      expect(launchCommands['macos'], equals('open'));
      expect(launchCommands['windows'], equals('start'));
    });

    test('| returns null for unsupported platforms', () {
      expect(launchCommands['unsupported'], isNull);
    });

    test('| returns the command for the current platform', () {
      expect(launchCommands[operatingSystemIdentifier], isNotNull);
    });
  });
}

final class _ReportTestFile extends Fake implements File {
  _ReportTestFile({
    required this.path,
    bool Function()? existsSync,
    void Function({bool recursive, bool exclusive})? createSync,
    Stream<List<int>> Function([int? start, int? end])? openRead,
    DateTime Function()? lastModifiedSync,
    List<String> Function(Encoding encoding)? readAsLinesSync,
    void Function(
      List<int> bytes, {
      FileMode mode,
      bool flush,
    })? writeAsBytesSync,
    void Function(
      String contents, {
      FileMode mode,
      Encoding encoding,
      bool flush,
    })? writeAsStringSync,
  })  : _existsSync = existsSync,
        _createSync = createSync,
        _openRead = openRead,
        _lastModifiedSync = lastModifiedSync,
        _readAsLinesSync = readAsLinesSync,
        _writeAsBytesSync = writeAsBytesSync,
        _writeAsStringSync = writeAsStringSync;

  @override
  final String path;

  final bool Function()? _existsSync;

  final void Function({bool recursive, bool exclusive})? _createSync;

  final Stream<List<int>> Function([int? start, int? end])? _openRead;

  final DateTime Function()? _lastModifiedSync;

  final List<String> Function(Encoding encoding)? _readAsLinesSync;

  final void Function(
    List<int> bytes, {
    FileMode mode,
    bool flush,
  })? _writeAsBytesSync;

  final void Function(
    String contents, {
    FileMode mode,
    Encoding encoding,
    bool flush,
  })? _writeAsStringSync;

  @override
  Directory get parent => Directory(p.dirname(path));

  @override
  bool existsSync() {
    if (_existsSync case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  void createSync({
    bool recursive = false,
    bool exclusive = false,
  }) {
    if (_createSync case final cb?) {
      return cb(
        recursive: recursive,
        exclusive: exclusive,
      );
    }
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (_openRead case final cb?) return cb(start, end);
    throw UnimplementedError();
  }

  @override
  DateTime lastModifiedSync() {
    if (_lastModifiedSync case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    if (_readAsLinesSync case final cb?) return cb(encoding);
    throw UnimplementedError();
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    if (_writeAsBytesSync case final cb?) {
      return cb(
        bytes,
        mode: mode,
        flush: flush,
      );
    }
    throw UnimplementedError();
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (_writeAsStringSync case final cb?) {
      return cb(
        contents,
        mode: mode,
        encoding: encoding,
        flush: flush,
      );
    }
    throw UnimplementedError();
  }
}
