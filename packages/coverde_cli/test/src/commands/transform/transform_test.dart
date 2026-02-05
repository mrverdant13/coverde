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

Presets can be defined in coverde.yaml under transformations.<name>.''';

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
          'without modifying files', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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
      });

      test(
          '--${TransformCommand.explainFlag} with preset '
          '| prints steps with preset chain suffix', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
              '--${TransformCommand.explainFlag}',
              '--${TransformCommand.transformationsOption}',
              'preset=my-preset',
            ]);
          },
          getCurrentDirectory: () => directory,
        );

        verify(
          () => logger.info(
            '1. keep-by-regex pattern=lib/.*   (from preset my-preset)',
          ),
        ).called(1);
      });

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=keep-by-regex=<regex> '
          '| keeps only files matching regex', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=skip-by-regex=<regex> '
          '| skips files matching regex', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=keep-by-glob=<glob> '
          '| keeps only files matching glob', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=skip-by-glob=<glob> '
          '| skips files matching glob', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          // Long CLI option usage
          // ignore: lines_longer_than_80_chars
          '--${TransformCommand.transformationsOption}=keep-by-coverage=<comparison> '
          '| keeps only files matching coverage comparison', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=relative=<base-path> '
          '| rewrites paths to be relative to base path', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.modeOption}=w '
          '| overrides output file content', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          '--${TransformCommand.modeOption}=a '
          '| appends to output file content', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

      test(
          'when coverde.yaml is invalid '
          '| throws $CoverdeTransformInvalidConfigFileFailure', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'transform',
                  '--${TransformCommand.inputOption}',
                  inputPath,
                ]);

            expect(
              action,
              throwsA(isA<CoverdeTransformInvalidConfigFileFailure>()),
            );
          },
          getCurrentDirectory: () => directory,
        );
      });

      test(
          '| throws $CoverdeTransformFileReadFailure '
          'when reading coverde.yaml fails', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final inputFile = File(inputPath)
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
                readAsStringSync: () => throw FileSystemException(
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

      test(
          '--${TransformCommand.inputOption}=<absent_file> '
          '| throws $CoverdeTransformTraceFileNotFoundFailure', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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
      });

      test(
          '--${TransformCommand.inputOption}=<file> '
          '--${TransformCommand.outputOption}=<file> '
          '--${TransformCommand.transformationsOption}=preset=<name> '
          '| expands preset from coverde.yaml and applies steps', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              'transform',
              '--${TransformCommand.inputOption}',
              inputPath,
              '--${TransformCommand.outputOption}',
              outputPath,
              '--${TransformCommand.transformationsOption}',
              'preset=my-preset',
            ]);
          },
          getCurrentDirectory: () => directory,
        );

        final outContent = File(outputPath).readAsStringSync();
        expect(outContent, contains('lib/foo.dart'));
        expect(outContent, isNot(contains('test/foo_test.dart')));
        expect(outContent, isNot(contains('bar.g.dart')));
      });

      test(
          '--${TransformCommand.transformationsOption}=<unsupported> '
          '| throws $CoverdeTransformInvalidTransformCliOptionFailure',
          () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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
      });

      test(
          '--${TransformCommand.inputOption}=<trace_file> '
          '--${TransformCommand.outputOption}=<output_file> '
          '| throws $CoverdeTransformDirectoryCreateFailure '
          'when output directory creation fails', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
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
                isA<CoverdeTransformDirectoryCreateFailure>().having(
                  (e) => e.directoryPath,
                  'directoryPath',
                  p.dirname(outputPath),
                ),
              ),
            );
          },
          createDirectory: (path) => _TransformTestDirectory(path: path),
        );
      });

      test(
          '--${TransformCommand.inputOption}=<trace_file> '
          '--${TransformCommand.outputOption}=<output_file> '
          '| throws $CoverdeTransformFileWriteFailure '
          'when output file write fails', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final inputPath = p.join(directory.path, 'in.info');
        final inputFile = File(inputPath)
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
          createFile: (filePath) {
            if (p.basename(filePath) == 'in.info') return inputFile;
            if (p.basename(filePath) == 'out.info') {
              return _TransformTestFile(
                path: filePath,
                open: () => Future<RandomAccessFile>.error(
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

      test(
          '--${TransformCommand.inputOption}=<trace_file> '
          '| throws $CoverdeTransformFileReadFailure '
          'when trace file read fails', () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-transform-test-');
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
          createFile: (path) {
            if (p.basename(path) == 'in.info') {
              return _TransformTestFile(
                path: path,
                openRead: ([start, end]) => Stream<List<int>>.error(
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
  })  : _open = open,
        _openRead = openRead,
        _readAsStringSync = readAsStringSync;

  final Future<RandomAccessFile> Function()? _open;
  final Stream<List<int>> Function([int? start, int? end])? _openRead;
  final String Function()? _readAsStringSync;

  @override
  final String path;

  @override
  Directory get parent => Directory(p.dirname(path));

  @override
  Future<RandomAccessFile> open({
    FileMode mode = FileMode.read,
  }) async {
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
}
