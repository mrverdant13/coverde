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
  group('coverde check', () {
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
        verifyNoMoreInteractions(logger);
      },
    );

    test(
      '| description',
      () {
        const expected = '''
Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.
This parameter indicates the minimum value for the coverage to be accepted.
''';

        final result = CheckCommand().description;

        expect(result.trim(), expected.trim());
      },
    );

    test(
      '''--${CheckCommand.fileCoverageLogLevelOptionName}=${FileCoverageLogLevel.none.identifier} '''
      '''<min_coverage> '''
      '''| meets the minimum coverage''',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'check',
          'fixtures',
          'partially_covered_proj',
        ]);
        final projectDir = Directory(projectPath);

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'check',
              '--${CheckCommand.fileCoverageLogLevelOptionName}',
              FileCoverageLogLevel.none.identifier,
              '${50}',
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
      '''--${CheckCommand.inputOptionName}=<empty_trace_file> '''
      '''<min_coverage> '''
      '''| fails when trace file is empty''',
      () async {
        final emptyTraceFilePath = p.joinAll([
          'test',
          'src',
          'commands',
          'check',
          'fixtures',
          'empty.lcov.info',
        ]);
        Future<void> action() => cmdRunner.run([
              'check',
              '--${CheckCommand.inputOptionName}',
              emptyTraceFilePath,
              '${50}',
            ]);
        expect(
          action,
          throwsA(
            isA<CoverdeCheckEmptyTraceFileFailure>().having(
              (e) => e.traceFilePath,
              'traceFilePath',
              p.absolute(emptyTraceFilePath),
            ),
          ),
        );
      },
    );

    test(
      '''--${CheckCommand.fileCoverageLogLevelOptionName}=${FileCoverageLogLevel.none.identifier} '''
      '<min_coverage> '
      '| fails when coverage is below minimum',
      () async {
        final currentDirectory = Directory.current;
        final projectPath = p.joinAll([
          currentDirectory.path,
          'test',
          'src',
          'commands',
          'check',
          'fixtures',
          'partially_covered_proj',
        ]);

        Future<void> action() => IOOverrides.runZoned(
              () async {
                await cmdRunner.run([
                  'check',
                  '--${CheckCommand.fileCoverageLogLevelOptionName}',
                  FileCoverageLogLevel.none.identifier,
                  '${75}',
                ]);
              },
              getCurrentDirectory: () => Directory(projectPath),
            );

        await expectLater(
          action,
          throwsA(
            isA<CoverdeCheckCoverageBelowMinimumFailure>()
                .having(
                  (failure) => failure.minimumCoverage,
                  'minimumCoverage',
                  75,
                )
                .having(
                  (failure) => failure.actualCoverage,
                  'actualCoverage',
                  lessThan(75),
                ),
          ),
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
      '--${CheckCommand.inputOptionName}=<absent_file> '
      '<min_coverage> '
      '| fails when trace file does not exist',
      () async {
        final directory = Directory.systemTemp.createTempSync();
        final absentFilePath = p.join(directory.path, 'absent.lcov.info');
        final absentFile = File(absentFilePath);
        const minCoverage = 50;
        expect(absentFile.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              'check',
              '--${CheckCommand.inputOptionName}',
              absentFilePath,
              '$minCoverage',
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeCheckTraceFileNotFoundFailure>().having(
              (e) => e.traceFilePath,
              'traceFilePath',
              p.absolute(absentFilePath),
            ),
          ),
        );
        directory.deleteSync(recursive: true);
      },
    );

    test(
      '--${CheckCommand.inputOptionName}=<trace_file> '
      '<min_coverage> '
      '| throws $CoverdeCheckTraceFileReadFailure '
      'when trace file read fails',
      () async {
        final directory = Directory.systemTemp.createTempSync();
        addTearDown(() => directory.deleteSync(recursive: true));
        final traceFilePath = p.join(directory.path, 'trace.lcov.info');
        File(traceFilePath).createSync();
        const minCoverage = 50;

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'check',
                  '--${CheckCommand.inputOptionName}',
                  traceFilePath,
                  '$minCoverage',
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeCheckTraceFileReadFailure>().having(
                  (e) => e.traceFilePath,
                  'traceFilePath',
                  p.absolute(traceFilePath),
                ),
              ),
            );
          },
          createFile: (path) {
            if (p.basename(path) == 'trace.lcov.info') {
              return _CheckTraceFileReadTestFile(
                path: path,
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
      },
    );

    test(
      '--${CheckCommand.fileCoverageLogLevelOptionName}=<invalid> '
      '<min_coverage> '
      '| fails when --${CheckCommand.fileCoverageLogLevelOptionName} '
      'is invalid',
      () async {
        const invalidLogLevel = 'invalid-log-level';
        final directory = Directory.systemTemp.createTempSync();
        final traceFilePath = p.join(directory.path, 'trace.lcov.info');
        File(traceFilePath).createSync(recursive: true);
        addTearDown(() => directory.deleteSync(recursive: true));
        const minCoverage = 50;

        Future<void> action() => cmdRunner.run([
              'check',
              '--${CheckCommand.inputOptionName}',
              traceFilePath,
              '--${CheckCommand.fileCoverageLogLevelOptionName}',
              invalidLogLevel,
              '$minCoverage',
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
      '| fails when more than one argument is provided',
      () async {
        Future<void> action() => cmdRunner.run(['check', '10', '20']);

        expect(
          action,
          throwsA(isA<CoverdeCheckMoreThanOneArgumentFailure>()),
        );
      },
    );

    test(
      '| fails when no minimum expected coverage value',
      () async {
        Future<void> action() => cmdRunner.run(['check']);

        expect(
          action,
          throwsA(
            isA<CoverdeCheckMissingMinimumCoverageThresholdFailure>().having(
              (e) => e.invalidInputDescription,
              'invalidInputDescription',
              'Missing minimum coverage threshold.',
            ),
          ),
        );
      },
    );

    test(
      '<non-numeric> | fails when minimum coverage value is non-numeric',
      () async {
        const invalidMinCoverage = 'str';

        Future<void> action() => cmdRunner.run([
              'check',
              invalidMinCoverage,
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeCheckInvalidMinimumCoverageThresholdFailure>().having(
              (e) => e.invalidInputDescription,
              'invalidInputDescription',
              'Invalid minimum coverage threshold.\n'
                  'It should be a positive number not greater than 100 '
                  '[0.0, 100.0].',
            ),
          ),
        );
      },
    );
  });
}

final class _CheckTraceFileReadTestFile extends Fake implements File {
  _CheckTraceFileReadTestFile({
    required this.path,
    Stream<List<int>> Function([int? start, int? end])? openRead,
  }) : _openRead = openRead;

  @override
  final String path;

  final Stream<List<int>> Function([int? start, int? end])? _openRead;

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (_openRead case final cb?) return cb(start, end);
    throw UnimplementedError();
  }
}
