import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    'coverde filter',
    () {
      late Logger logger;
      late CoverdeCommandRunner cmdRunner;

      setUp(
        () {
          logger = MockLogger();
          cmdRunner = CoverdeCommandRunner(logger: logger);
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

Filter the coverage info by ignoring data related to files with paths that matches the given FILTERS.
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
        '--${FilterCommand.filtersOption}=<patterns> '
        '| filters trace file',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          const patterns = <String>['ignored_source'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = path.joinAll([
            directory.path,
            'original.info',
          ]);
          final filteredFilePath = path.joinAll([
            directory.path,
            'actual.info',
          ]);
          final acceptedSourceFilePath = path.joinAll([
            'path',
            'to',
            'accepted_source_file.dart',
          ]);
          final ignoredSourceFilePath = path.joinAll([
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
          final originalFileIncludeFileThatMatchPatterns =
              originalTraceFile.includeFileThatMatchPatterns(patterns);
          final filesDataToBeRemoved =
              originalTraceFile.sourceFilesCovData.where(
            (d) => patternsRegex.any(
              (r) => r.hasMatch(d.source.path),
            ),
          );

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(originalFileIncludeFileThatMatchPatterns, isTrue);

          await cmdRunner.run([
            'filter',
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent = acceptedSourceFileData;
          final filteredFileIncludeFileThatMatchPatterns =
              TraceFile.parse(filteredFileContent)
                  .includeFileThatMatchPatterns(patterns);
          expect(filteredFileIncludeFileThatMatchPatterns, isFalse);
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
        '--${FilterCommand.filtersOption}=<patterns> '
        '| filters trace file with absolute paths',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          const patterns = <String>['ignored_source'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = path.join(
            directory.path,
            'original.info',
          );
          final filteredFilePath = path.join(
            directory.path,
            'actual.info',
          );
          final acceptedSourceFilePath = path.joinAll([
            if (Platform.isWindows) 'C:' else '/',
            'path',
            'to',
            'accepted_source_file.dart',
          ]);
          final ignoredSourceFilePath = path.joinAll([
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
          final originalFileIncludeFileThatMatchPatterns =
              originalTraceFile.includeFileThatMatchPatterns(patterns);
          final filesDataToBeRemoved =
              originalTraceFile.sourceFilesCovData.where(
            (d) => patternsRegex.any(
              (r) => r.hasMatch(d.source.path),
            ),
          );

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(originalFileIncludeFileThatMatchPatterns, isTrue);

          await cmdRunner.run([
            'filter',
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent = acceptedSourceFileData;
          final filteredFileIncludeFileThatMatchPatterns =
              TraceFile.parse(filteredFileContent)
                  .includeFileThatMatchPatterns(patterns);
          expect(filteredFileIncludeFileThatMatchPatterns, isFalse);
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
        '--${FilterCommand.filtersOption}=<patterns> '
        '| filters trace file and resolves relative paths',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          const patterns = <String>['ignored_source'];
          final baseDirectory = path.join('root', 'parent');
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = path.join(
            directory.path,
            'original.info',
          );
          final filteredFilePath = path.join(
            directory.path,
            'actual.info',
          );
          final acceptedSourceFilePath = path.joinAll([
            'path',
            'to',
            'accepted_source_file.dart',
          ]);
          final ignoredSourceFilePath = path.joinAll([
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
          final originalFileIncludeFileThatMatchPatterns =
              originalTraceFile.includeFileThatMatchPatterns(patterns);
          final filesDataToBeRemoved =
              originalTraceFile.sourceFilesCovData.where(
            (d) => patternsRegex.any(
              (r) => r.hasMatch(d.source.path),
            ),
          );

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(originalFileIncludeFileThatMatchPatterns, isTrue);

          await cmdRunner.run([
            'filter',
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.baseDirectoryOptionName}',
            baseDirectory,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent = '''
SF:${path.relative(acceptedSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
'''
              .trim();
          final filteredTraceFile = TraceFile.parse(filteredFileContent);
          final expectedTraceFile =
              TraceFile.parse(expectedFilteredFileContent);
          final filteredFileIncludeFileThatMatchPatterns =
              filteredTraceFile.includeFileThatMatchPatterns(patterns);
          expect(filteredFileIncludeFileThatMatchPatterns, isFalse);
          expect(
            filteredTraceFile,
            expectedTraceFile,
            reason: 'Error: Non-matching trace files.',
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
        '--${FilterCommand.filtersOption}=<patterns> '
        '| filters trace file and resolves relative paths '
        '(including absolute paths)',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          const patterns = <String>['ignored_source'];
          final baseDirectory = path.join('root', 'parent');
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = path.join(
            directory.path,
            'original.info',
          );
          final filteredFilePath = path.join(
            directory.path,
            'actual.info',
          );
          final acceptedSourceFilePath = path.joinAll([
            'path',
            'to',
            'accepted_source_file.dart',
          ]);
          final ignoredSourceFilePath = path.joinAll([
            'path',
            'to',
            'ignored_source_file.dart',
          ]);
          final absoluteSourceFilePath = path.joinAll([
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
          final originalFileIncludeFileThatMatchPatterns =
              originalTraceFile.includeFileThatMatchPatterns(patterns);
          final filesDataToBeRemoved =
              originalTraceFile.sourceFilesCovData.where(
            (d) => patternsRegex.any(
              (r) => r.hasMatch(d.source.path),
            ),
          );

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(originalFileIncludeFileThatMatchPatterns, isTrue);

          await cmdRunner.run([
            'filter',
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.baseDirectoryOptionName}',
            baseDirectory,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent = '''
SF:${path.relative(acceptedSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
SF:${path.relative(absoluteSourceFilePath, from: baseDirectory)}
DA:1,1
LF:1
LH:1
end_of_record
'''
              .trim();
          final filteredTraceFile = TraceFile.parse(filteredFileContent);
          final expectedTraceFile =
              TraceFile.parse(expectedFilteredFileContent);
          final filteredFileIncludeFileThatMatchPatterns =
              filteredTraceFile.includeFileThatMatchPatterns(patterns);
          expect(filteredFileIncludeFileThatMatchPatterns, isFalse);
          expect(
            filteredTraceFile,
            expectedTraceFile,
            reason: 'Error: Non-matching trace files.',
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
        '--${FilterCommand.filtersOption}=<patterns> '
        '| fails when trace file does not exist',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          const patterns = <String>['ignored_source'];
          final absentFilePath = path.join(
            directory.path,
            'absent.info',
          );
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                absentFilePath,
                '--${FilterCommand.filtersOption}',
                patterns.join(','),
              ]);

          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '--${FilterCommand.inputOption}=<trace_file> '
        '--${FilterCommand.filtersOption}=<invalid_regex> '
        '| fails when regex pattern is invalid',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          addTearDown(() => directory.delete(recursive: true));
          final traceFilePath = path.join(directory.path, 'test.info');
          File(traceFilePath)
            ..createSync()
            ..writeAsStringSync('''
SF:test.dart
DA:1,1
LF:1
LH:1
end_of_record
''');
          const invalidPattern = '[invalid'; // Missing closing bracket

          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                traceFilePath,
                '--${FilterCommand.filtersOption}',
                invalidPattern,
              ]);

          expect(
            action,
            throwsA(
              isA<UsageException>().having(
                (e) => e.message,
                'message',
                contains(
                  'Invalid regex pattern in --filters: `[invalid`',
                ),
              ),
            ),
          );
        },
      );

      test(
        '--${FilterCommand.inputOption}=<trace_file> '
        '--${FilterCommand.filtersOption}=<multiple_invalid_patterns> '
        '| fails when any regex pattern is invalid',
        () async {
          final directory =
              Directory.systemTemp.createTempSync('coverde-filter-test-');
          addTearDown(() => directory.delete(recursive: true));
          final traceFilePath = path.join(directory.path, 'test.info');
          File(traceFilePath)
            ..createSync()
            ..writeAsStringSync('''
SF:test.dart
DA:1,1
LF:1
LH:1
end_of_record
''');
          const validPattern = 'test';
          const invalidPattern = '(unclosed'; // Invalid regex

          Future<void> action() => cmdRunner.run([
                'filter',
                '--${FilterCommand.inputOption}',
                traceFilePath,
                '--${FilterCommand.filtersOption}',
                '$validPattern,$invalidPattern',
              ]);

          expect(
            action,
            throwsA(
              isA<UsageException>().having(
                (e) => e.message,
                'message',
                contains('Invalid regex pattern in --filters: `(unclosed`'),
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
          final inputFilePath = path.join(
            directory.path,
            'input.info',
          );
          File(inputFilePath)
            ..createSync()
            ..writeAsStringSync(newContent);

          for (final testCase in testCases) {
            final outputFilePath = path.join(
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
    },
  );
}
