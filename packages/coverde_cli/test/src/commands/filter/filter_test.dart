import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

extension on String {
  String get fixturePath => path.join(
        'test/src/commands/filter/fixtures/',
        this,
      );
}

void main() {
  group(
    '''

GIVEN a trace file filterer command''',
    () {
      late CommandRunner<void> cmdRunner;
      late MockStdout out;
      late FilterCommand filterCmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          out = MockStdout();
          filterCmd = FilterCommand(out: out);
          cmdRunner.addCommand(filterCmd);
        },
      );

      tearDown(
        () {
          verifyNoMoreInteractions(out);
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
Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given FILTERS.
The coverage data is taken from the INPUT_LCOV_FILE file and the result is appended to the OUTPUT_LCOV_FILE file.

All the relative paths in the resulting coverage trace file will be prefixed with PATHS_PARENT, if provided.
If an absolute path is found in the coverage trace file, the process will fail.
''';

          // ACT
          final result = filterCmd.description;

          // ASSERT
          expect(result.trim(), expected.trim());
        },
      );

      test(
        '''

AND an existing trace file to filter
├─ THAT does not contain any absolute path
AND a set of unquoted patterns to be filtered
WHEN the command is invoked
THEN a filtered trace file should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>['.g.dart'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = 'original.relative.lcov.info'.fixturePath;
          final filteredFilePath =
              'unquoted.relative.filtered.lcov.info'.fixturePath;
          final expectedFilteredFilePath =
              'expected.unquoted.relative.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          final expectedFilteredFile = File(expectedFilteredFilePath);
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

          // ACT
          await cmdRunner.run([
            filterCmd.name,
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          // ASSERT
          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent =
              expectedFilteredFile.readAsStringSync();
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
              () => out.writeln('<$path> coverage data ignored.'),
            ).called(1);
          }
        },
      );

      test(
        '''

AND an existing trace file to filter
├─ THAT contains at least one absolute path
AND a set of unquoted patterns to be filtered
WHEN the command is invoked
THEN a filtered trace file should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>['.g.dart'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = 'original.absolute.lcov.info'.fixturePath;
          final filteredFilePath =
              'unquoted.absolute.filtered.lcov.info'.fixturePath;
          final expectedFilteredFilePath =
              'expected.unquoted.absolute.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          final expectedFilteredFile = File(expectedFilteredFilePath);
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

          // ACT
          await cmdRunner.run([
            filterCmd.name,
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          // ASSERT
          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent =
              expectedFilteredFile.readAsStringSync();
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
              () => out.writeln('<$path> coverage data ignored.'),
            ).called(1);
          }
        },
      );

      test(
        '''

AND an existing trace file to filter
├─ THAT does not contain any absolute path
AND a set of raw patterns to be filtered
WHEN the command is invoked
THEN a filtered trace file should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>[r'\.g\.dart'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = 'original.relative.lcov.info'.fixturePath;
          final filteredFilePath =
              'raw.relative.filtered.lcov.info'.fixturePath;
          final expectedFilteredFilePath =
              'expected.raw.relative.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          final expectedFilteredFile = File(expectedFilteredFilePath);
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

          // ACT
          await cmdRunner.run([
            filterCmd.name,
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          // ASSERT
          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent =
              expectedFilteredFile.readAsStringSync();
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
              () => out.writeln('<$path> coverage data ignored.'),
            ).called(1);
          }
        },
      );

      test(
        '''

AND an existing trace file to filter
├─ THAT contains at least one absolute path
AND a set of raw patterns to be filtered
WHEN the command is invoked
THEN a filtered trace file should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>[r'\.g\.dart'];
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = 'original.absolute.lcov.info'.fixturePath;
          final filteredFilePath =
              'raw.absolute.filtered.lcov.info'.fixturePath;
          final expectedFilteredFilePath =
              'expected.raw.absolute.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          final expectedFilteredFile = File(expectedFilteredFilePath);
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

          // ACT
          await cmdRunner.run([
            filterCmd.name,
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          // ASSERT
          const splitter = LineSplitter();
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent =
              expectedFilteredFile.readAsStringSync();
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
              () => out.writeln('<$path> coverage data ignored.'),
            ).called(1);
          }
        },
      );

      test(
        '''

AND an existing trace file to filter
├─ THAT does not contain any absolute path
AND a set of raw patterns to be filtered
AND a path to be used as prefix for the tested file paths
WHEN the command is invoked
THEN a filtered trace file should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>[r'\.g\.dart'];
          const pathsPrefix = 'root/parent/';
          final patternsRegex = patterns.map(RegExp.new);
          final originalFilePath = 'original.relative.lcov.info'.fixturePath;
          final filteredFilePath =
              'prefixed.relative.filtered.lcov.info'.fixturePath;
          final expectedFilteredFilePath =
              'expected.prefixed.relative.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          final expectedFilteredFile = File(expectedFilteredFilePath);
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

          // ACT
          await cmdRunner.run([
            filterCmd.name,
            '--${FilterCommand.inputOption}',
            originalFilePath,
            '--${FilterCommand.outputOption}',
            filteredFilePath,
            '--${FilterCommand.pathsParentOption}',
            pathsPrefix,
            '--${FilterCommand.filtersOption}',
            patterns.join(','),
          ]);

          // ASSERT
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileContent = filteredFile.readAsStringSync();
          final expectedFilteredFileContent =
              expectedFilteredFile.readAsStringSync();
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
              () => out.writeln('<$path> coverage data ignored.'),
            ).called(1);
          }
        },
      );

      test(
        '''

AND a trace file content to filter
├─ THAT contains at least one absolute path
AND a set of raw patterns to be filtered
AND a path to be used as prefix for the tested file paths
WHEN the command is invoked
THEN an error indicating the issue should be thrown
AND no filtered file should be created
''',
        () async {
          // ARRANGE
          const patterns = <String>[r'\.g\.dart'];
          const pathsPrefix = 'root/parent/';
          final originalFilePath = 'original.absolute.lcov.info'.fixturePath;
          final filteredFilePath =
              'prefixed.absolute.filtered.lcov.info'.fixturePath;
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath);
          if (filteredFile.existsSync()) {
            filteredFile.deleteSync(recursive: true);
          }
          final originalTraceFile = TraceFile.parse(
            originalFile.readAsStringSync(),
          );
          final originalFileIncludeFileThatMatchPatterns =
              originalTraceFile.includeFileThatMatchPatterns(patterns);

          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(originalFileIncludeFileThatMatchPatterns, isTrue);

          // ACT
          Future<void> action() => cmdRunner.run([
                filterCmd.name,
                '--${FilterCommand.inputOption}',
                originalFilePath,
                '--${FilterCommand.outputOption}',
                filteredFilePath,
                '--${FilterCommand.pathsParentOption}',
                pathsPrefix,
                '--${FilterCommand.filtersOption}',
                patterns.join(','),
              ]);

          // ASSERT
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isFalse);
          expect(action, throwsA(isA<UsageException>()));
          verify(() => out.writeln(any()));
        },
      );

      test(
        '''

AND a non-existing trace file to filter
AND a set of patterns to be filtered
WHEN the command is invoked
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const patterns = <String>['.g.dart'];
          final absentFilePath = 'absent.lcov.info'.fixturePath;
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                filterCmd.name,
                '--${FilterCommand.inputOption}',
                absentFilePath,
                '--${FilterCommand.filtersOption}',
                patterns.join(','),
              ]);

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
