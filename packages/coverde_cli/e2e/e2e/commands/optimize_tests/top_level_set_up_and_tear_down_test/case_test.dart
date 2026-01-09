@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('Top level `setUp` and `tearDown`', () async {
    const testCases = [
      (
        caseName: 'dart',
        projectDirName: 'dart_project',
        testCommand: 'dart test --no-color --reporter compact',
      ),
      (
        caseName: 'flutter',
        projectDirName: 'flutter_project',
        testCommand: 'flutter test --reporter compact',
      ),
    ];
    final currentDirectory = Directory.current;
    for (final testCase in testCases) {
      final (:caseName, :projectDirName, :testCommand) = testCase;
      final projectDirPath = p.joinAll([
        currentDirectory.path,
        'e2e',
        'commands',
        'optimize_tests',
        'top_level_set_up_and_tear_down_test',
        'fixtures',
        projectDirName,
      ]);
      {
        // Clean generated files
        final process = await () async {
          final [
            command,
            ...arguments,
          ] = 'git clean -dfX .'.split(' ');
          return Process.start(
            command,
            arguments,
            workingDirectory: projectDirPath,
            runInShell: true,
          );
        }();
        final stderrMessages = <String>[];
        final (exitCode, _) = await (
          process.exitCode,
          process.stderr.forEach((data) {
            final message = utf8.decode(data);
            stderrMessages.add(message);
          }),
        ).wait;
        expect(
          (exitCode, stderrMessages),
          isA<(int, List<String>)>()
              .having(
                (it) => it.$1,
                'exitCode',
                isZero,
              )
              .having(
                (it) => it.$2,
                'stderrMessages',
                isEmpty,
              ),
          reason: '$caseName project',
        );
      }

      {
        // Install dependencies
        final process = await () async {
          final [
            command,
            ...arguments,
          ] = '$caseName pub get'.split(' ');
          return Process.start(
            command,
            arguments,
            workingDirectory: projectDirPath,
            runInShell: true,
          );
        }();
        final stderrMessages = <String>[];
        final (exitCode, _) = await (
          process.exitCode,
          process.stderr.forEach((data) {
            final message = utf8.decode(data);
            stderrMessages.add(message);
          }),
        ).wait;
        expect(
          (exitCode, stderrMessages),
          isA<(int, List<String>)>()
              .having(
                (it) => it.$1,
                'exitCode',
                isZero,
              )
              .having(
                (it) => it.$2,
                'stderrMessages',
                isEmpty,
              ),
          reason: '$caseName project',
        );
      }

      {
        // Generate _test.dart files from _test.dart.tmp files
        final files = Directory(projectDirPath)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_test.dart.tmp'));
        for (final file in files) {
          file.copySync(file.path.replaceAll('_test.dart.tmp', '_test.dart'));
        }
      }

      final optimizedTestFilePath = p.joinAll([
        projectDirPath,
        'test',
        'optimized_test.dart',
      ]);

      final optimizedTestFile = File(optimizedTestFilePath);
      {
        // Ensure the optimized test file does not exist
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync();
        }
        expect(
          optimizedTestFile.existsSync(),
          isFalse,
          reason: 'optimized test file should not exist ($caseName project)',
        );
      }

      {
        // Optimize tests
        final process = await () async {
          final [
            command,
            ...arguments,
          ] = 'dart run coverde optimize-tests'.split(' ');
          return Process.start(
            command,
            arguments,
            workingDirectory: projectDirPath,
            runInShell: true,
          );
        }();
        final stdoutMessages = <String>[];
        final stderrMessages = <String>[];
        final (exitCode, _, _) = await (
          process.exitCode,
          process.stdout.forEach((data) {
            final message = utf8.decode(data);
            stdoutMessages.add(message);
          }),
          process.stderr.forEach((data) {
            final message = utf8.decode(data);
            stderrMessages.add(message);
          }),
        ).wait;
        expect(
          (exitCode, stdoutMessages, stderrMessages),
          isA<(int, List<String>, List<String>)>()
              .having(
                (it) => it.$1,
                'exitCode',
                isZero,
              )
              .having(
                (it) => it.$2,
                'stdoutMessages',
                isEmpty,
              )
              .having(
                (it) => it.$3,
                'stderrMessages',
                isEmpty,
              ),
          reason: '$caseName project',
        );
        expect(
          optimizedTestFile.existsSync(),
          isTrue,
          reason: 'optimized test file should exist ($caseName project)',
        );
      }

      {
        // Run optimized test
        final process = await () async {
          final [
            command,
            ...arguments,
          ] = '$testCommand test/optimized_test.dart'.split(' ');
          return Process.start(
            command,
            arguments,
            workingDirectory: projectDirPath,
            runInShell: true,
          );
        }();
        final stdoutMessages = <String>[];
        final stderrMessages = <String>[];
        final (exitCode, _, _) = await (
          process.exitCode,
          process.stdout.forEach((data) {
            final message = utf8.decode(data);
            stdoutMessages.add(message);
          }),
          process.stderr.forEach((data) {
            final message = utf8.decode(data);
            stderrMessages.add(message);
          }),
        ).wait;
        expect(
          (exitCode, stdoutMessages, stderrMessages),
          isA<(int, List<String>, List<String>)>()
              .having(
                (it) => it.$1,
                'exitCode',
                isZero,
              )
              .having(
                (it) => it.$2,
                'stdoutMessages',
                anyElement(contains('+4: All tests passed!')),
              )
              .having(
                (it) => it.$3,
                'stderrMessages',
                isEmpty,
              ),
          reason: '$caseName project',
        );
      }
    }
  });
}
