import 'dart:async';
import 'dart:convert';

import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:glob/glob.dart';
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
  group('coverde filter', () {
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
Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given EXCLUDE_GLOB.
The coverage data is taken from the INPUT_LCOV_FILE file and the result is appended to the OUTPUT_LCOV_FILE file.

All the relative paths in the resulting coverage trace file will be resolved relative to the <base-directory>, if provided.
''';

        final result = FilterCommand().description;

        expect(result.trim(), expected.trim());
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.outputOption}=<output_file> '
      '--${FilterCommand.excludeOptionName}=<glob_pattern> '
      '| filters trace file',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        const excludePattern = '**/ignored_source*';
        final excludeGlob = Glob(excludePattern);
        final originalFilePath = p.joinAll([
          directory.path,
          'original.info',
        ]);
        final filteredFilePath = p.joinAll([
          directory.path,
          'actual.info',
        ]);
        final acceptedSourceFilePath = p.joinAll([
          'path',
          'to',
          'accepted_source_file.dart',
        ]);
        final ignoredSourceFilePath = p.joinAll([
          'path',
          'to',
          'ignored_source_file.dart',
        ]);
        final acceptedSourceFileData = '''
SF:$acceptedSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final ignoredSourceFileData = '''
SF:$ignoredSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final originalFileContent =
            '$acceptedSourceFileData\n$ignoredSourceFileData';
        final originalFile = File(originalFilePath)
          ..createSync()
          ..writeAsStringSync(originalFileContent);
        final filteredFile = File(filteredFilePath);
        if (filteredFile.existsSync()) {
          filteredFile.deleteSync(recursive: true);
        }
        final originalTraceFile = TraceFile.parse(
          originalFile.readAsStringSync(),
        );
        final originalFileIncludesFileThatMatchesGlob =
            originalTraceFile.includesFileThatMatchesGlob(excludeGlob);
        final filesDataToBeRemoved = originalTraceFile.sourceFilesCovData.where(
          (d) => excludeGlob.matches(d.source.path),
        );

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isFalse);
        expect(originalFileIncludesFileThatMatchesGlob, isTrue);

        await cmdRunner.run([
          'filter',
          '--${FilterCommand.inputOption}',
          originalFilePath,
          '--${FilterCommand.outputOption}',
          filteredFilePath,
          '--${FilterCommand.excludeOptionName}',
          excludePattern,
        ]);

        const splitter = LineSplitter();
        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isTrue);
        final filteredFileContent = filteredFile.readAsStringSync();
        final expectedFilteredFileContent = acceptedSourceFileData;
        final filteredFileIncludesFileThatMatchesGlob =
            TraceFile.parse(filteredFileContent)
                .includesFileThatMatchesGlob(excludeGlob);
        expect(filteredFileIncludesFileThatMatchesGlob, isFalse);
        expect(
          splitter.convert(filteredFileContent),
          splitter.convert(expectedFilteredFileContent),
          reason: 'Error: Non-matching filtered file content.',
        );
        for (final fileData in filesDataToBeRemoved) {
          final path = fileData.source.path;
          verify(
            () => logger.detail('<$path> coverage data ignored.'),
          ).called(1);
        }
        directory.deleteSync(recursive: true);
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.outputOption}=<output_file> '
      '--${FilterCommand.excludeOptionName}=<glob_pattern> '
      '| filters trace file with absolute paths',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        const excludePattern = '/**/ignored_source*';
        final excludeGlob = Glob(excludePattern);
        final originalFilePath = p.join(
          directory.path,
          'original.info',
        );
        final filteredFilePath = p.join(
          directory.path,
          'actual.info',
        );
        final acceptedSourceFilePath = p.joinAll([
          if (Platform.isWindows) 'C:' else '/',
          'path',
          'to',
          'accepted_source_file.dart',
        ]);
        final ignoredSourceFilePath = p.joinAll([
          if (Platform.isWindows) 'C:' else '/',
          'path',
          'to',
          'ignored_source_file.dart',
        ]);
        final acceptedSourceFileData = '''
SF:$acceptedSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final ignoredSourceFileData = '''
SF:$ignoredSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final originalFileContent =
            '$acceptedSourceFileData\n$ignoredSourceFileData';
        final originalFile = File(originalFilePath)
          ..createSync()
          ..writeAsStringSync(originalFileContent);
        final filteredFile = File(filteredFilePath);
        if (filteredFile.existsSync()) {
          filteredFile.deleteSync(recursive: true);
        }
        final originalTraceFile = TraceFile.parse(
          originalFile.readAsStringSync(),
        );
        final originalFileIncludesFileThatMatchesGlob =
            originalTraceFile.includesFileThatMatchesGlob(excludeGlob);
        final filesDataToBeRemoved = originalTraceFile.sourceFilesCovData.where(
          (d) => excludeGlob.matches(d.source.path),
        );

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isFalse);
        expect(
          originalFileIncludesFileThatMatchesGlob,
          isTrue,
          reason: [
            'Original file includes file that matches glob.',
            'Original file:',
            originalFileContent,
          ].join('\n'),
        );

        await cmdRunner.run([
          'filter',
          '--${FilterCommand.inputOption}',
          originalFilePath,
          '--${FilterCommand.outputOption}',
          filteredFilePath,
          '--${FilterCommand.excludeOptionName}',
          excludePattern,
        ]);

        const splitter = LineSplitter();
        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isTrue);
        final filteredFileContent = filteredFile.readAsStringSync();
        final expectedFilteredFileContent = acceptedSourceFileData;
        final filteredFileIncludesFileThatMatchesGlob =
            TraceFile.parse(filteredFileContent)
                .includesFileThatMatchesGlob(excludeGlob);
        expect(filteredFileIncludesFileThatMatchesGlob, isFalse);
        expect(
          splitter.convert(filteredFileContent),
          splitter.convert(expectedFilteredFileContent),
          reason: 'Error: Non-matching filtered file content.',
        );
        for (final fileData in filesDataToBeRemoved) {
          final path = fileData.source.path;
          verify(
            () => logger.detail('<$path> coverage data ignored.'),
          ).called(1);
        }
        directory.deleteSync(recursive: true);
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.outputOption}=<output_file> '
      '--${FilterCommand.baseDirectoryOptionName}=<base_dir> '
      '--${FilterCommand.excludeOptionName}=<glob_pattern> '
      '| filters trace file and resolves relative paths',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        const excludePattern = '**/ignored_source*';
        final baseDirectory = p.join('root', 'parent');
        final excludeGlob = Glob(excludePattern);
        final originalFilePath = p.join(
          directory.path,
          'original.info',
        );
        final filteredFilePath = p.join(
          directory.path,
          'actual.info',
        );
        final acceptedSourceFilePath = p.joinAll([
          'path',
          'to',
          'accepted_source_file.dart',
        ]);
        final ignoredSourceFilePath = p.joinAll([
          'path',
          'to',
          'ignored_source_file.dart',
        ]);
        final acceptedSourceFileData = '''
SF:$acceptedSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final ignoredSourceFileData = '''
SF:$ignoredSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final originalFileContent = '''
$acceptedSourceFileData
$ignoredSourceFileData
''';
        final originalFile = File(originalFilePath)
          ..createSync()
          ..writeAsStringSync(originalFileContent);
        final filteredFile = File(filteredFilePath);
        if (filteredFile.existsSync()) {
          filteredFile.deleteSync(recursive: true);
        }
        final originalTraceFile = TraceFile.parse(
          originalFile.readAsStringSync(),
        );
        final originalFileIncludesFileThatMatchesGlob =
            originalTraceFile.includesFileThatMatchesGlob(excludeGlob);
        final filesDataToBeRemoved = originalTraceFile.sourceFilesCovData.where(
          (d) => excludeGlob.matches(d.source.path),
        );

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isFalse);
        expect(originalFileIncludesFileThatMatchesGlob, isTrue);

        await cmdRunner.run([
          'filter',
          '--${FilterCommand.inputOption}',
          originalFilePath,
          '--${FilterCommand.outputOption}',
          filteredFilePath,
          '--${FilterCommand.baseDirectoryOptionName}',
          baseDirectory,
          '--${FilterCommand.excludeOptionName}',
          excludePattern,
        ]);

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isTrue);
        final filteredFileContent = filteredFile.readAsStringSync();
        final expectedFilteredFileContent = '''
SF:${p.relative(acceptedSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final filteredTraceFile = TraceFile.parse(filteredFileContent);
        final expectedTraceFile = TraceFile.parse(expectedFilteredFileContent);
        final filteredFileIncludesFileThatMatchesGlob =
            filteredTraceFile.includesFileThatMatchesGlob(excludeGlob);
        expect(filteredFileIncludesFileThatMatchesGlob, isFalse);
        expect(
          filteredTraceFile,
          expectedTraceFile,
          reason: [
            'Error: Non-matching trace files.',
            'Filtered trace file:',
            filteredFileContent,
            'Expected trace file:',
            expectedFilteredFileContent,
          ].join('\n'),
        );
        for (final fileData in filesDataToBeRemoved) {
          final path = fileData.source.path;
          verify(
            () => logger.detail('<$path> coverage data ignored.'),
          ).called(1);
        }
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.outputOption}=<output_file> '
      '--${FilterCommand.baseDirectoryOptionName}=<base_dir> '
      '--${FilterCommand.excludeOptionName}=<glob_pattern> '
      '| filters trace file and resolves relative paths '
      '(including absolute paths)',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        const excludePattern = '{**,../..}/**/ignored_source*';
        final baseDirectory = p.join('root', 'parent');
        final excludeGlob = Glob(excludePattern);
        final originalFilePath = p.join(
          directory.path,
          'original.info',
        );
        final filteredFilePath = p.join(
          directory.path,
          'actual.info',
        );
        final acceptedSourceFilePath = p.joinAll([
          'path',
          'to',
          'accepted_source_file.dart',
        ]);
        final ignoredSourceFilePath = p.joinAll([
          'path',
          'to',
          'ignored_source_file.dart',
        ]);
        final absoluteSourceFilePath = p.joinAll([
          if (Platform.isWindows) 'C:' else '/',
          'path',
          'to',
          'absolute_source_file.dart',
        ]);
        final acceptedSourceFileData = '''
SF:$acceptedSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final ignoredSourceFileData = '''
SF:$ignoredSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final absoluteSourceFileData = '''
SF:$absoluteSourceFilePath
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final originalFileContent = '''
$acceptedSourceFileData
$ignoredSourceFileData
$absoluteSourceFileData
''';
        final originalFile = File(originalFilePath)
          ..createSync()
          ..writeAsStringSync(originalFileContent);
        final filteredFile = File(filteredFilePath);
        if (filteredFile.existsSync()) {
          filteredFile.deleteSync(recursive: true);
        }
        final originalTraceFile = TraceFile.parse(
          originalFile.readAsStringSync(),
        );
        final originalFileIncludesFileThatMatchesGlob =
            originalTraceFile.includesFileThatMatchesGlob(excludeGlob);
        final filesDataToBeRemoved = originalTraceFile.sourceFilesCovData.where(
          (d) => excludeGlob.matches(d.source.path),
        );

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isFalse);
        expect(originalFileIncludesFileThatMatchesGlob, isTrue);

        await cmdRunner.run([
          'filter',
          '--${FilterCommand.inputOption}',
          originalFilePath,
          '--${FilterCommand.outputOption}',
          filteredFilePath,
          '--${FilterCommand.baseDirectoryOptionName}',
          baseDirectory,
          '--${FilterCommand.excludeOptionName}',
          excludePattern,
        ]);

        expect(originalFile.existsSync(), isTrue);
        expect(filteredFile.existsSync(), isTrue);
        final filteredFileContent = filteredFile.readAsStringSync();
        final expectedFilteredFileContent = '''
SF:${p.relative(acceptedSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
SF:${p.relative(absoluteSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final filteredTraceFile = TraceFile.parse(filteredFileContent);
        final expectedTraceFile = TraceFile.parse(expectedFilteredFileContent);
        final filteredFileIncludesFileThatMatchesGlob =
            filteredTraceFile.includesFileThatMatchesGlob(excludeGlob);
        expect(filteredFileIncludesFileThatMatchesGlob, isFalse);
        expect(
          filteredTraceFile,
          expectedTraceFile,
          reason: [
            'Error: Non-matching trace files.',
            'Filtered trace file:',
            filteredFileContent,
            'Expected trace file:',
            expectedFilteredFileContent,
          ].join('\n'),
        );
        for (final fileData in filesDataToBeRemoved) {
          final path = fileData.source.path;
          verify(
            () => logger.detail('<$path> coverage data ignored.'),
          ).called(1);
        }
      },
    );

    test(
      '--${FilterCommand.inputOption}=<absent_file> '
      '--${FilterCommand.excludeOptionName}=<glob_pattern> '
      '| fails when trace file does not exist',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        const excludePattern = '**/ignored_source*';
        final absentFilePath = p.join(
          directory.path,
          'absent.info',
        );
        final absentFile = File(absentFilePath);
        expect(absentFile.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              'filter',
              '--${FilterCommand.inputOption}',
              absentFilePath,
              '--${FilterCommand.excludeOptionName}',
              excludePattern,
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeFilterTraceFileNotFoundFailure>().having(
              (e) => e.traceFilePath,
              'traceFilePath',
              p.absolute(absentFilePath),
            ),
          ),
        );
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.excludeOptionName}=<invalid_glob> '
      '| fails when glob pattern is invalid',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        addTearDown(() => directory.delete(recursive: true));
        final traceFilePath = p.join(directory.path, 'test.info');
        File(traceFilePath)
          ..createSync()
          ..writeAsStringSync('''
SF:test.dart
DA:1,1
LF:1
LH:1
end_of_record
''');
        const invalidPattern = '{invalid'; // Missing closing brace

        Future<void> action() => cmdRunner.run([
              'filter',
              '--${FilterCommand.inputOption}',
              traceFilePath,
              '--${FilterCommand.excludeOptionName}',
              invalidPattern,
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeFilterInvalidGlobPatternFailure>().having(
              (e) => e.invalidGlobPattern,
              'invalidGlobPattern',
              invalidPattern,
            ),
          ),
        );
      },
    );

    test(
      '--${FilterCommand.inputOption}=<trace_file> '
      '--${FilterCommand.outputOption}=<output_file> '
      '--${FilterCommand.modeOption}=<mode> '
      '| filters trace file and handles different modes',
      () async {
        final existingContent = '''
SF:existing.dart
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final newContent = '''
SF:new.dart
DA:1,1
LF:1
LH:1
end_of_record
'''
            .trim();
        final testCases = [
          (
            mode: 'a',
            outputFileName: 'a.lcov.info',
            expectedContent: '$existingContent\n$newContent',
          ),
          (
            mode: 'w',
            outputFileName: 'w.lcov.info',
            expectedContent: newContent,
          ),
        ];
        final directory =
            Directory.systemTemp.createTempSync('coverde-filter-test-');
        addTearDown(() => directory.delete(recursive: true));
        final inputFilePath = p.join(
          directory.path,
          'input.info',
        );
        File(inputFilePath)
          ..createSync()
          ..writeAsStringSync(newContent);

        for (final testCase in testCases) {
          final outputFilePath = p.join(
            directory.path,
            testCase.outputFileName,
          );
          File(outputFilePath)
            ..createSync()
            ..writeAsStringSync(existingContent);

          await cmdRunner.run([
            'filter',
            '--${FilterCommand.inputOption}',
            inputFilePath,
            '--${FilterCommand.outputOption}',
            outputFilePath,
            '--${FilterCommand.modeOption}',
            testCase.mode,
          ]);

          expect(
            File(outputFilePath).existsSync(),
            isTrue,
            reason: 'Output file does not exist '
                '(mode: ${testCase.mode}).',
          );
          expect(
            File(outputFilePath).readAsStringSync(),
            testCase.expectedContent,
            reason: 'Filtered file content does not match '
                '(mode: ${testCase.mode}).',
          );
        }
      },
    );

    test(
        '--${FilterCommand.inputOption}=<trace_file> '
        '--${FilterCommand.outputOption}=<output_file> '
        '| throws $CoverdeFilterDirectoryCreateFailure '
        'when output directory creation fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-filter-test-');
      addTearDown(() => directory.delete(recursive: true));
      final inputFilePath = p.join(directory.path, 'input.info');
      File(inputFilePath)
        ..createSync()
        ..writeAsStringSync('SF:test.dart\nend_of_record');

      final outputFilePath = p.join(directory.path, 'output.info');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                inputFilePath,
                '--${FilterCommand.outputOption}',
                outputFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeFilterDirectoryCreateFailure>().having(
                (e) => e.directoryPath,
                'directoryPath',
                p.dirname(outputFilePath),
              ),
            ),
          );
        },
        createDirectory: (path) => _FilterTestDirectory(path: path),
      );
    });

    test(
        '--${FilterCommand.inputOption}=<trace_file> '
        '--${FilterCommand.outputOption}=<output_file> '
        '| throws $CoverdeFilterFileWriteFailure '
        'when output file write fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-filter-test-');
      addTearDown(() => directory.delete(recursive: true));
      final inputFilePath = p.join(directory.path, 'input.info');
      final inputFile = File(inputFilePath)
        ..createSync()
        ..writeAsStringSync('SF:lib/some_test.dart\nend_of_record');
      final outputFilePath = p.join(directory.path, 'output.info');
      final testFilePath = p.joinAll([
        directory.path,
        'lib',
        'some_test.dart',
      ]);
      final testFile = File(testFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}');

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                inputFilePath,
                '--${FilterCommand.outputOption}',
                outputFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeFilterFileWriteFailure>().having(
                (e) => e.filePath,
                'filePath',
                outputFilePath,
              ),
            ),
          );
        },
        createFile: (path) {
          if (p.basename(path) == 'input.info') {
            return inputFile;
          }
          if (p.basename(path) == 'some_test.dart') {
            return testFile;
          }
          if (p.basename(path) == 'output.info') {
            return _FilterTestFile(
              path: path,
              open: () => Future<RandomAccessFile>.error(
                FileSystemException('Fake file write error', path),
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
        '--${FilterCommand.inputOption}=<trace_file> '
        '--${FilterCommand.outputOption}=<output_file> '
        '| throws $CoverdeFilterTraceFileReadFailure '
        'when trace file read fails', () async {
      final directory =
          Directory.systemTemp.createTempSync('coverde-filter-test-');
      addTearDown(() => directory.delete(recursive: true));
      final inputFilePath = p.join(directory.path, 'input.info');
      File(inputFilePath).createSync();
      final outputFilePath = p.join(directory.path, 'output.info');
      final outputFile = File(outputFilePath);

      await IOOverrides.runZoned(
        () async {
          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                inputFilePath,
                '--${FilterCommand.outputOption}',
                outputFilePath,
              ]);

          expect(
            action,
            throwsA(
              isA<CoverdeFilterTraceFileReadFailure>().having(
                (e) => e.traceFilePath,
                'traceFilePath',
                inputFilePath,
              ),
            ),
          );
        },
        createFile: (path) {
          if (p.basename(path) == 'input.info') {
            return _FilterTestFile(
              path: path,
              openRead: ([start, end]) => Stream<List<int>>.error(
                FileSystemException('Fake file read error', path),
              ),
            );
          }
          if (p.basename(path) == 'output.info') {
            return outputFile;
          }
          throw UnsupportedError(
            'This file $path should not be read in this test',
          );
        },
      );
    });
  });
}

final class _FilterTestDirectory extends Fake implements Directory {
  _FilterTestDirectory({
    required this.path,
  });

  @override
  final String path;

  @override
  void createSync({bool recursive = false}) {
    throw FileSystemException('Fake directory creation error', path);
  }
}

final class _FilterTestFile extends Fake implements File {
  _FilterTestFile({
    required this.path,
    Future<RandomAccessFile> Function()? open,
    Stream<List<int>> Function([int? start, int? end])? openRead,
  })  : _open = open,
        _openRead = openRead;

  final Future<RandomAccessFile> Function()? _open;
  final Stream<List<int>> Function([int? start, int? end])? _openRead;

  @override
  final String path;

  @override
  Directory get parent => Directory(p.dirname(path));

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    if (_open case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (_openRead case final cb?) return cb(start, end);
    throw UnimplementedError();
  }
}
