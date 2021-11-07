import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/filter/filter.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../utils/mocks.dart';

void main() {
  group(
    '''

GIVEN a tracefile filterer command''',
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

AND an existing tracefile to filter
AND a set of patterns to be filtered
WHEN the command is invoqued
THEN a filtered tracefile should be created
├─ BY dumping the filtered content to the default destination
''',
        () async {
          // ARRANGE
          const patterns = <String>['.g.dart'];
          final patternsRegex = patterns.map((p) => RegExp(p));
          const originalFilePath = 'test/fixtures/filter/original.lcov.info';
          const filteredFilePath = 'test/fixtures/filter/filtered.lcov.info';
          final originalFile = File(originalFilePath);
          final filteredFile = File(filteredFilePath)
            ..deleteSync(recursive: true);
          final originalTracefile = Tracefile.parse(
            originalFile.readAsStringSync(),
          );
          final originalFileIncludeFileThatMatchPatterns =
              originalTracefile.includeFileThatMatchPatterns(patterns);
          final filesDataToBeRemoved =
              originalTracefile.sourceFilesCovData.where(
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
            '--${FilterCommand.originOption}',
            originalFilePath,
            '--${FilterCommand.destinationOption}',
            filteredFilePath,
            '--${FilterCommand.ignorePatternsOption}',
            patterns.join(','),
          ]);

          // ASSERT
          expect(originalFile.existsSync(), isTrue);
          expect(filteredFile.existsSync(), isTrue);
          final filteredFileIncludeFileThatMatchPatterns = Tracefile.parse(
            filteredFile.readAsStringSync(),
          ).includeFileThatMatchPatterns(patterns);
          expect(filteredFileIncludeFileThatMatchPatterns, isFalse);
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

AND a non-existing tracefile to filter
AND a set of patterns to be filtered
WHEN the command is invoqued
THEN an error indicating the issue should be thrown
''',
        () async {
          // ARRANGE
          const patterns = <String>['.g.dart'];
          const absentFilePath = 'test/fixtures/filter/absent.lcov.info';
          final absentFile = File(absentFilePath);
          expect(absentFile.existsSync(), isFalse);

          // ACT
          Future<void> action() => cmdRunner.run([
                filterCmd.name,
                '--${FilterCommand.originOption}',
                absentFilePath,
                '--${FilterCommand.ignorePatternsOption}',
                patterns.join(','),
              ]);

          // ASSERT
          expect(action, throwsA(isA<StateError>()));
        },
      );
    },
  );
}
