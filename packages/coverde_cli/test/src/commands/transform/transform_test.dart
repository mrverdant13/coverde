import 'dart:async';
import 'dart:convert' show Encoding, utf8;

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

void main() {
  group('$TransformCommand', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      packageVersionManager = _MockPackageVersionManager();
      when(() => packageVersionManager.logger).thenReturn(logger);
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: packageVersionManager,
      );
    });

    tearDown(() {
      verifyNoMoreInteractions(logger);
    });

    test('description | returns transform command description', () {
      const expected = '''
Transform a coverage trace file.

Apply a sequence of transformations to the coverage data.
The coverage data is taken from the INPUT_LCOV_FILE file and written to the OUTPUT_LCOV_FILE file.

Presets can be defined in coverde.yaml under the `transformations` key.''';

      final result = TransformCommand().description;

      expect(result.trim(), expected.trim());
    });

    test('name | returns "transform"', () {
      expect(TransformCommand().name, 'transform');
    });

    test('takesArguments | returns false', () {
      expect(TransformCommand().takesArguments, isFalse);
    });

    group('run', () {
      test(
        '--${TransformCommand.explainFlag} | prints resolved steps and exits '
        'without modifying files',
        () async {
          final directory = Directory.systemTemp.createTempSync(
            'coverde-transform-test-',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          final inputPath = p.join(directory.path, 'coverage.info');
          File(inputPath)
            ..createSync()
            ..writeAsStringSync('''
SF:lib/foo.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

          await cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'keep-by-regex=lib/.*',
            '--${TransformCommand.transformationsOption}',
            'skip-by-glob=**/*.g.dart',
          ]);

          verify(
            () => logger.info('1. keep-by-regex pattern=lib/.*'),
          ).called(1);
          verify(
            () => logger.info('2. skip-by-glob pattern=**/*.g.dart'),
          ).called(1);
          expect(
            File(p.join(directory.path, 'transformed.info')).existsSync(),
            isFalse,
          );
        },
      );

      test('--${TransformCommand.explainFlag} with preset '
          '| prints steps with preset chain suffix', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final configPath = p.join(directory.path, 'coverde.yaml');
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(
            'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
          );
        File(configPath)
          ..createSync()
          ..writeAsStringSync('''
transformations:
  my-preset:
    - type: keep-by-regex
      regex: "lib/.*"
''');

        await IOOverrides.runZoned(() async {
          await cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset=my-preset',
          ]);
        }, getCurrentDirectory: () => directory);

        verify(
          () => logger.info(
            '1. keep-by-regex pattern=lib/.*   (from preset my-preset)',
          ),
        ).called(1);
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=keep-by-regex=<regex> '
          '| keeps only files matching regex', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/src/foo.dart';
        const skippedPath = 'test/foo_test.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
LF:1
LH:1
end_of_record
SF:$skippedPath
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          r'keep-by-regex=lib[/\\\\].*',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=skip-by-regex=<regex> '
          '| skips files matching regex', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/foo.dart';
        const skippedPath = 'test/bar_test.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
LF:1
LH:1
end_of_record
SF:$skippedPath
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          r'skip-by-regex=test[/\\\\].*',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=keep-by-glob=<glob> '
          '| keeps only files matching glob', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/foo.dart';
        const skippedPath = 'bin/bar.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
LF:1
LH:1
end_of_record
SF:$skippedPath
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'keep-by-glob=lib/*.dart',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=skip-by-glob=<glob> '
          '| skips files matching glob', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/foo.dart';
        const skippedPath = 'lib/foo.g.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
LF:1
LH:1
end_of_record
SF:$skippedPath
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'skip-by-glob=**/*.g.dart',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          // Long CLI option usage
          // ignore: lines_longer_than_80_chars
          '--${TransformCommand.transformationsOption}=keep-by-coverage=<comparison> '
          '| keeps only files matching coverage comparison', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/foo.dart';
        const skippedPath = 'lib/bar.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
DA:2,2
LF:2
LH:2
end_of_record
SF:$skippedPath
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
          ''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'keep-by-coverage=gte|75',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          // Long CLI option usage
          // ignore: lines_longer_than_80_chars
          '--${TransformCommand.transformationsOption}=skip-by-coverage=<comparison> '
          '| skips files matching coverage comparison', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const keptPath = 'lib/foo.dart';
        const skippedPath = 'lib/bar.dart';
        const inputContent = '''
SF:$keptPath
DA:1,1
DA:2,2
LF:2
LH:2
end_of_record
SF:$skippedPath
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
          ''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'skip-by-coverage=lt|75',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('SF:$keptPath'));
        expect(outContent, isNot(contains('SF:$skippedPath')));
      });

      test('--${TransformCommand.transformationsOption}=keep-by-coverage '
          '| leaves a file with no line rate unmatched', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const inputContent = '''
SF:lib/lines.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:lib/functions.dart
FN:4,only
FNDA:1,only
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'keep-by-coverage=gte|0',
        ]);

        final kept = File(outputPath).readAsStringSync();
        expect(kept, contains('SF:lib/lines.dart'));
        expect(kept, isNot(contains('FN:4,only')));

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.modeOption}',
          'w',
          '--${TransformCommand.transformationsOption}',
          'skip-by-coverage=lt|100',
        ]);

        final skipped = File(outputPath).readAsStringSync();
        expect(skipped, contains('SF:lib/lines.dart'));
        expect(skipped, contains('FN:4,only'));
        expect(skipped, contains('FNDA:1,only'));
      });

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=relative=<base-path> '
          '| rewrites paths to be relative to base path', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        final absolutePath = p.joinAll([directory.path, 'lib', 'foo.dart']);
        final inputContent = '''
SF:$absolutePath
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.transformationsOption}',
          'relative=${directory.path}',
        ]);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('lib'));
        expect(outContent, contains('foo.dart'));
        expect(outContent, isNot(contains(directory.path)));
      });

      test('--${TransformCommand.modeOption}=w '
          '| overrides output file content', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const existingContent = '''
SF:existing.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        const newContent = '''
SF:new.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(newContent);
        File(outputPath)
          ..createSync()
          ..writeAsStringSync(existingContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.modeOption}',
          'w',
        ]);

        expect(File(outputPath).readAsStringSync(), newContent.trim());
      });

      test('--${TransformCommand.modeOption}=a '
          '| appends to output file content', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        const existingContent = '''
SF:existing.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        const newContent = '''
SF:new.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(newContent);
        File(outputPath)
          ..createSync()
          ..writeAsStringSync(existingContent);

        await cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          inputPath,
          '--${TransformCommand.outputOption}',
          outputPath,
          '--${TransformCommand.modeOption}',
          'a',
        ]);

        expect(
          File(outputPath).readAsStringSync(),
          '$existingContent\n${newContent.trim()}',
        );
      });

      test('when coverde.yaml is invalid '
          '| throws $CoverdeTransformInvalidConfigFileFailure', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final configPath = p.join(directory.path, 'coverde.yaml');
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(
            'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
          );
        File(configPath)
          ..createSync()
          ..writeAsStringSync('invalid: [');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
          ]);

          expect(
            action,
            throwsA(isA<CoverdeTransformInvalidConfigFileFailure>()),
          );
        }, getCurrentDirectory: () => directory);
      });

      test('| throws $CoverdeTransformFileReadFailure '
          'when reading coverde.yaml fails', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final inputFile =
            File(inputPath)
              ..createSync()
              ..writeAsStringSync(
                'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
              );
        final configPath = p.join(directory.path, 'coverde.yaml');
        File(configPath).createSync();

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
            ]);

            expect(
              action,
              throwsA(
                isA<CoverdeTransformFileReadFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  configPath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (filePath) {
            if (filePath.endsWith('coverde.yaml') ||
                p.normalize(filePath) == p.normalize(configPath)) {
              return _TransformTestFile(
                path: filePath,
                readAsStringSync:
                    () =>
                        throw FileSystemException(
                          'Cannot read config',
                          filePath,
                        ),
              );
            }
            if (p.normalize(filePath) == p.normalize(inputPath)) {
              return inputFile;
            }
            throw UnsupportedError(
              'This file $filePath should not be opened in this test',
            );
          },
        );
      });

      test('--${TransformCommand.inputOption}=<absent_file> '
          '| throws $CoverdeTransformTraceFileNotFoundFailure', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final absentPath = p.join(directory.path, 'absent.info');
        expect(File(absentPath).existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
          'transform',
          '--${TransformCommand.inputOption}',
          absentPath,
        ]);

        expect(
          action,
          throwsA(
            isA<CoverdeTransformTraceFileNotFoundFailure>().having(
              (e) => e.traceFilePath,
              'traceFilePath',
              p.absolute(absentPath),
            ),
          ),
        );
      });

      test(
        '--${TransformCommand.transformationsOption}=<invalid_regex> '
        '| throws $CoverdeTransformInvalidTransformCliOptionFailure',
        () async {
          final directory = Directory.systemTemp.createTempSync(
            'coverde-transform-test-',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          final inputPath = p.join(directory.path, 'in.info');
          File(inputPath)
            ..createSync()
            ..writeAsStringSync(
              'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
            );
          const invalidRegex = '[invalid';

          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.transformationsOption}',
            'keep-by-regex=$invalidRegex',
          ]);

          expect(
            action,
            throwsA(isA<CoverdeTransformInvalidTransformCliOptionFailure>()),
          );
        },
      );

      test('--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=preset=<name> '
          '| expands preset from coverde.yaml and applies steps', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        final configPath = p.join(directory.path, 'coverde.yaml');
        const configYaml = r'''
transformations:
  my-preset:
    - type: keep-by-regex
      regex: "lib[/\\\\].*"
    - type: skip-by-glob
      glob: "**/*.g.dart"
''';
        const inputContent = '''
SF:lib/foo.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:test/foo_test.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:lib/bar.g.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(inputContent);
        File(configPath)
          ..createSync()
          ..writeAsStringSync(configYaml);

        await IOOverrides.runZoned(() async {
          await cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.outputOption}',
            outputPath,
            '--${TransformCommand.transformationsOption}',
            'preset=my-preset',
          ]);
        }, getCurrentDirectory: () => directory);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('lib/foo.dart'));
        expect(outContent, isNot(contains('test/foo_test.dart')));
        expect(outContent, isNot(contains('bar.g.dart')));
      });

      test('--${TransformCommand.explainFlag} '
          '--${TransformCommand.transformationsOption}=preset '
          '| prints the authored file and nested preset', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final sharedDir = Directory(p.join(directory.path, 'shared'))
          ..createSync();
        final sharedConfig = File(p.join(sharedDir.path, 'coverde.yaml'))
          ..writeAsStringSync('''
transformations:
  outer:
    - type: preset
      name: inner
  inner:
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');
        final inputPath = p.join(directory.path, 'in.info');
        final sharedRelative = '${p.basename(sharedDir.path)}/coverde.yaml';
        File(inputPath).writeAsStringSync(
          'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
        );

        await IOOverrides.runZoned(() async {
          await cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: $sharedRelative, name: outer}',
          ]);
        }, getCurrentDirectory: () => directory);

        verify(
          () => logger.info(
            '1. skip-by-glob pattern=**/*.g.dart   '
            '(from preset outer in shared/coverde.yaml → inner)',
          ),
        ).called(1);
        expect(sharedConfig.existsSync(), isTrue);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| applies steps from the external preset', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final configPath = p.join(directory.path, 'shared.yaml');
        final inputPath = p.join(directory.path, 'in.info');
        final outputPath = p.join(directory.path, 'out.info');
        File(configPath).writeAsStringSync(r'''
transformations:
  ci-workflow:
    - type: keep-by-regex
      regex: "lib[/\\\\].*"
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');
        const inputContent = '''
SF:lib/foo.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:test/foo_test.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:lib/bar.g.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        File(inputPath).writeAsStringSync(inputContent);
        final quotedPath = "'${configPath.replaceAll("'", "''")}'";

        await IOOverrides.runZoned(() async {
          await cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.outputOption}',
            outputPath,
            '--${TransformCommand.transformationsOption}',
            'preset={file: $quotedPath, name: ci-workflow}',
          ]);
        }, getCurrentDirectory: () => directory);

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('lib/foo.dart'));
        expect(outContent, isNot(contains('test/foo_test.dart')));
        expect(outContent, isNot(contains('bar.g.dart')));
      });

      test(
        '--${TransformCommand.transformationsOption}=preset=<name> '
        '| resolves an external preset relative to the file that cites it',
        () async {
          final directory = Directory.systemTemp.createTempSync(
            'coverde-transform-test-',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          final appDir = Directory(p.join(directory.path, 'packages', 'app'))
            ..createSync(recursive: true);
          final sharedDir = Directory(
            p.join(directory.path, 'packages', 'shared', 'nested'),
          )..createSync(recursive: true);
          File(p.join(appDir.path, 'coverde.yaml')).writeAsStringSync('''
transformations:
  local:
    - type: preset
      file: ../shared/coverde.yaml
      name: mid
''');
          File(
            p.join(directory.path, 'packages', 'shared', 'coverde.yaml'),
          ).writeAsStringSync('''
transformations:
  mid:
    - type: preset
      file: nested/coverde.yaml
      name: leaf
''');
          File(p.join(sharedDir.path, 'coverde.yaml')).writeAsStringSync('''
transformations:
  leaf:
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');
          final inputPath = p.join(appDir.path, 'in.info');
          File(inputPath).writeAsStringSync(
            'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
          );

          await IOOverrides.runZoned(() async {
            await cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
              '--${TransformCommand.explainFlag}',
              '--${TransformCommand.transformationsOption}',
              'preset=local',
            ]);
          }, getCurrentDirectory: () => appDir);

          verify(
            () => logger.info(
              '1. skip-by-glob pattern=**/*.g.dart   '
              '(from preset local → mid in ../shared/coverde.yaml → '
              'leaf in nested/coverde.yaml)',
            ),
          ).called(1);
        },
      );

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformExternalPresetFileNotFoundFailure '
          'when the file is missing', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final missingPath = p.join(directory.path, 'missing.yaml');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: missing.yaml, name: ci-workflow}',
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformExternalPresetFileNotFoundFailure>().having(
                (failure) => failure.filePath,
                'filePath',
                p.normalize(missingPath),
              ),
            ),
          );
        }, getCurrentDirectory: () => directory);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformFileReadFailure '
          'when the external file cannot be read', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final configPath = p.join(directory.path, 'shared.yaml');
        File(configPath).writeAsStringSync('''
transformations:
  ci-workflow:
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
              'transform',
              '--${TransformCommand.explainFlag}',
              '--${TransformCommand.transformationsOption}',
              'preset={file: shared.yaml, name: ci-workflow}',
            ]);

            expect(
              action,
              throwsA(
                isA<CoverdeTransformFileReadFailure>().having(
                  (failure) => failure.filePath,
                  'filePath',
                  p.normalize(configPath),
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (filePath) {
            if (p.normalize(filePath) == p.normalize(configPath)) {
              return _TransformTestFile(
                path: filePath,
                readAsStringSync:
                    () =>
                        throw FileSystemException(
                          'Cannot read external config',
                          filePath,
                        ),
              );
            }
            throw UnsupportedError(
              'This file $filePath should not be opened in this test',
            );
          },
        );
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformInvalidConfigFileFailure '
          'when the external file is invalid', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final configPath = p.join(directory.path, 'shared.yaml');
        File(configPath).writeAsStringSync('transformations: [');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: shared.yaml, name: ci-workflow}',
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformInvalidConfigFileFailure>().having(
                (failure) => failure.configPath,
                'configPath',
                p.normalize(configPath),
              ),
            ),
          );
        }, getCurrentDirectory: () => directory);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformUnknownExternalPresetFailure '
          'when the preset name is missing', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        File(p.join(directory.path, 'shared.yaml')).writeAsStringSync('''
transformations:
  other:
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: shared.yaml, name: missing}',
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformUnknownExternalPresetFailure>()
                  .having(
                    (failure) => failure.presetName,
                    'presetName',
                    'missing',
                  )
                  .having(
                    (failure) => failure.filePath,
                    'filePath',
                    'shared.yaml',
                  )
                  .having(
                    (failure) => failure.availablePresets,
                    'availablePresets',
                    ['other'],
                  ),
            ),
          );
        }, getCurrentDirectory: () => directory);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformExternalPresetCycleFailure '
          'when external presets form a cycle', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final aDir = Directory(p.join(directory.path, 'a'))..createSync();
        final bDir = Directory(p.join(directory.path, 'b'))..createSync();
        File(p.join(aDir.path, 'coverde.yaml')).writeAsStringSync('''
transformations:
  a-preset:
    - type: preset
      file: ../b/coverde.yaml
      name: b-preset
''');
        File(p.join(bDir.path, 'coverde.yaml')).writeAsStringSync('''
transformations:
  b-preset:
    - type: preset
      file: ../a/coverde.yaml
      name: a-preset
''');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: ../b/coverde.yaml, name: b-preset}',
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformExternalPresetCycleFailure>()
                  .having((failure) => failure.cycle, 'cycle', [
                    'b-preset in ../b/coverde.yaml',
                    'a-preset in ../a/coverde.yaml',
                    'b-preset in ../b/coverde.yaml',
                  ]),
            ),
          );
        }, getCurrentDirectory: () => aDir);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformExternalPresetCycleFailure '
          'when a directory symlink repeats the same preset', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final real = Directory(p.join(directory.path, 'real'))..createSync();
        File(p.join(real.path, 'coverde.yaml')).writeAsStringSync('''
transformations:
  loop:
    - type: preset
      file: via/coverde.yaml
      name: loop
''');
        try {
          Link(p.join(real.path, 'via')).createSync(real.path);
        } on FileSystemException {
          markTestSkipped('Directory symlinks are unavailable.');
        }

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.explainFlag}',
            '--${TransformCommand.transformationsOption}',
            'preset={file: coverde.yaml, name: loop}',
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformExternalPresetCycleFailure>().having(
                (failure) => failure.cycle,
                'cycle',
                ['loop in coverde.yaml', 'loop in via/coverde.yaml'],
              ),
            ),
          );
        }, getCurrentDirectory: () => real);
      });

      test('--${TransformCommand.transformationsOption}=preset '
          '| throws $CoverdeTransformFileReadFailure '
          'when the external file links cannot be resolved', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final configPath = p.join(directory.path, 'shared.yaml');
        File(configPath).writeAsStringSync('''
transformations:
  ci-workflow:
    - type: skip-by-glob
      glob: "**/*.g.dart"
''');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
              'transform',
              '--${TransformCommand.explainFlag}',
              '--${TransformCommand.transformationsOption}',
              'preset={file: shared.yaml, name: ci-workflow}',
            ]);

            expect(
              action,
              throwsA(
                isA<CoverdeTransformFileReadFailure>().having(
                  (failure) => failure.filePath,
                  'filePath',
                  p.normalize(configPath),
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (filePath) {
            if (p.normalize(filePath) == p.normalize(configPath)) {
              return _TransformTestFile(
                path: filePath,
                resolveSymbolicLinksSync:
                    () =>
                        throw FileSystemException(
                          'Cannot resolve external config',
                          filePath,
                        ),
              );
            }
            throw UnsupportedError(
              'This file $filePath should not be opened in this test',
            );
          },
        );
      });

      test(
        '--${TransformCommand.transformationsOption}=<unsupported> '
        '| throws $CoverdeTransformInvalidTransformCliOptionFailure',
        () async {
          final directory = Directory.systemTemp.createTempSync(
            'coverde-transform-test-',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          final inputPath = p.join(directory.path, 'in.info');
          File(inputPath)
            ..createSync()
            ..writeAsStringSync(
              'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
            );

          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.transformationsOption}',
            'unknown=value',
          ]);

          expect(
            action,
            throwsA(isA<CoverdeTransformInvalidTransformCliOptionFailure>()),
          );
        },
      );

      test('--${TransformCommand.inputOption}=<trace_file> '
          '--${TransformCommand.outputOption}=<output_file> '
          '| throws $CoverdeTransformDirectoryCreateFailure '
          'when output directory creation fails', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        File(inputPath)
          ..createSync()
          ..writeAsStringSync(
            'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
          );
        final outputPath = p.join(directory.path, 'out.info');

        await IOOverrides.runZoned(() async {
          Future<void> action() => cmdRunner.run([
            'transform',
            '--${TransformCommand.inputOption}',
            inputPath,
            '--${TransformCommand.outputOption}',
            outputPath,
          ]);

          expect(
            action,
            throwsA(
              isA<CoverdeTransformDirectoryCreateFailure>().having(
                (e) => e.directoryPath,
                'directoryPath',
                p.dirname(outputPath),
              ),
            ),
          );
        }, createDirectory: (path) => _TransformTestDirectory(path: path));
      });

      test('--${TransformCommand.inputOption}=<trace_file> '
          '--${TransformCommand.outputOption}=<output_file> '
          '| throws $CoverdeTransformFileWriteFailure '
          'when output file write fails', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final inputFile =
            File(inputPath)
              ..createSync()
              ..writeAsStringSync(
                'SF:lib/foo.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record',
              );
        final outputPath = p.join(directory.path, 'out.info');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
              '--${TransformCommand.outputOption}',
              outputPath,
            ]);

            expect(
              action,
              throwsA(
                isA<CoverdeTransformFileWriteFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  outputPath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (filePath) {
            if (p.basename(filePath) == 'in.info') return inputFile;
            if (p.basename(filePath) == 'out.info') {
              return _TransformTestFile(
                path: filePath,
                open:
                    () => Future<RandomAccessFile>.error(
                      FileSystemException('Fake file write error', filePath),
                    ),
              );
            }
            // Path from SF: line in trace is used to build CovFile; not opened.
            if (filePath.contains('foo.dart')) {
              return _TransformTestFile(path: filePath);
            }
            throw UnsupportedError(
              'This file $filePath should not be opened in this test',
            );
          },
        );
      });

      test('--${TransformCommand.inputOption}=<trace_file> '
          '| throws $CoverdeTransformFileReadFailure '
          'when trace file read fails', () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-transform-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        File(inputPath).createSync();
        final outputPath = p.join(directory.path, 'out.info');
        final outputFile = File(outputPath);

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
              '--${TransformCommand.outputOption}',
              outputPath,
            ]);

            expect(
              action,
              throwsA(
                isA<CoverdeTransformFileReadFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  inputPath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (path) {
            if (p.basename(path) == 'in.info') {
              return _TransformTestFile(
                path: path,
                openRead:
                    ([start, end]) => Stream<List<int>>.error(
                      FileSystemException('Fake file read error', path),
                    ),
              );
            }
            if (p.basename(path) == 'out.info') return outputFile;
            throw UnsupportedError(
              'This file $path should not be opened in this test',
            );
          },
        );
      });
    });
  });
}

final class _TransformTestDirectory extends Fake implements Directory {
  _TransformTestDirectory({required this.path});

  @override
  final String path;

  @override
  void createSync({bool recursive = false}) {
    throw FileSystemException('Fake directory creation error', path);
  }
}

final class _TransformTestFile extends Fake implements File {
  _TransformTestFile({
    required this.path,
    Future<RandomAccessFile> Function()? open,
    Stream<List<int>> Function([int? start, int? end])? openRead,
    String Function()? readAsStringSync,
    String Function()? resolveSymbolicLinksSync,
  }) : _open = open,
       _openRead = openRead,
       _readAsStringSync = readAsStringSync,
       _resolveSymbolicLinksSync = resolveSymbolicLinksSync;

  final Future<RandomAccessFile> Function()? _open;
  final Stream<List<int>> Function([int? start, int? end])? _openRead;
  final String Function()? _readAsStringSync;
  final String Function()? _resolveSymbolicLinksSync;

  @override
  final String path;

  @override
  Directory get parent => Directory(p.dirname(path));

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    if (_open case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (_openRead case final cb?) return cb(start, end);
    throw UnimplementedError();
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    final cb = _readAsStringSync;
    if (cb != null) return cb();
    throw UnimplementedError();
  }

  @override
  String resolveSymbolicLinksSync() {
    final cb = _resolveSymbolicLinksSync;
    if (cb != null) return cb();
    return path;
  }
}
