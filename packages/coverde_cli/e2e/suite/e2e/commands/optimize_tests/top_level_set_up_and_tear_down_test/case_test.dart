@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late final Directory temporaryDirectory;
  late final String coverdeExecutablePath;

  setUpAll(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'coverde-optimize-tests-e2e-',
    );
    final coverdeCliPath = p.normalize(
      p.join(Directory.current.path, '..', '..'),
    );
    final coverdeFileName = Platform.isWindows ? 'coverde.exe' : 'coverde';
    coverdeExecutablePath = p.join(temporaryDirectory.path, coverdeFileName);
    final compile = await Process.run(
      'dart',
      [
        'compile',
        'exe',
        p.join(coverdeCliPath, 'bin', 'coverde.dart'),
        '-o',
        coverdeExecutablePath,
      ],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );
    if (compile.exitCode != 0) {
      throw Exception(
        'Failed to compile coverde executable:\n${compile.stderr}',
      );
    }
  });

  tearDownAll(() async {
    temporaryDirectory.deleteSync(recursive: true);
  });

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
        final clean = await Process.run(
          'git',
          ['clean', '-dfX', '.'],
          workingDirectory: projectDirPath,
          runInShell: true,
        );
        expect(clean.exitCode, isZero, reason: '$caseName project');
      }

      {
        // Install dependencies.
        // Flutter/Dart may write bootstrap progress to stderr on Windows CI.
        final pubGet = await Process.run(
          caseName,
          ['pub', 'get'],
          workingDirectory: projectDirPath,
          runInShell: true,
        );
        expect(pubGet.exitCode, isZero, reason: '$caseName project');
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
        final process = await Process.start(
          coverdeExecutablePath,
          ['optimize-tests'],
          workingDirectory: projectDirPath,
          runInShell: true,
        );
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
        // Run optimized test. SDK tools may write progress to stderr.
        final [command, ...arguments] =
            '$testCommand test/optimized_test.dart'.split(' ');
        final process = await Process.start(
          command,
          arguments,
          workingDirectory: projectDirPath,
          runInShell: true,
        );
        final stdoutMessages = <String>[];
        final (exitCode, _, _) = await (
          process.exitCode,
          process.stdout.forEach((data) {
            stdoutMessages.add(utf8.decode(data));
          }),
          process.stderr.drain<void>(),
        ).wait;
        expect(
          (exitCode, stdoutMessages),
          isA<(int, List<String>)>()
              .having(
                (it) => it.$1,
                'exitCode',
                isZero,
              )
              .having(
                (it) => it.$2,
                'stdoutMessages',
                anyElement(contains('+4: All tests passed!')),
              ),
          reason: '$caseName project',
        );
      }
    }
  });
}
