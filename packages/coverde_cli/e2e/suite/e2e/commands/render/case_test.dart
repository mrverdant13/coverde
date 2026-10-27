@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late final Directory temporaryDirectory;
  late final String coverdeExecutablePath;
  late final String projectDirPath;
  late final String goldensDirPath;

  setUpAll(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'coverde-render-e2e-',
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

    projectDirPath = p.join(
      Directory.current.path,
      'e2e',
      'commands',
      'render',
      'fixtures',
      'project',
    );
    goldensDirPath = p.join(
      Directory.current.path,
      'e2e',
      'commands',
      'render',
      'goldens',
    );
  });

  tearDownAll(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  setUp(() {
    final buildDir = Directory(p.join(projectDirPath, 'build'));
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
  });

  test('lcov_like matches golden HTML report', () async {
    await _runRender(
      executable: coverdeExecutablePath,
      projectDirPath: projectDirPath,
      report: 'lcov_like',
    );
    _expectDirectoryMatchesGolden(
      actualDir: p.join(projectDirPath, 'build', 'lcov_like'),
      goldenDir: p.join(goldensDirPath, 'lcov_like'),
    );
  });

  test('istanbul_like matches golden HTML report', () async {
    await _runRender(
      executable: coverdeExecutablePath,
      projectDirPath: projectDirPath,
      report: 'istanbul_like',
    );
    _expectDirectoryMatchesGolden(
      actualDir: p.join(projectDirPath, 'build', 'istanbul_like'),
      goldenDir: p.join(goldensDirPath, 'istanbul_like'),
    );
  });

  test('coverde_value_plain matches golden console output', () async {
    final result = await _runRender(
      executable: coverdeExecutablePath,
      projectDirPath: projectDirPath,
      report: 'coverde_value_plain',
    );
    final golden = File(
      p.join(goldensDirPath, 'coverde_value_plain.txt'),
    ).readAsStringSync();
    expect(
      _normalizeNewlines(result.stdout as String),
      _normalizeNewlines(golden),
    );
  });

  test('coverde_value_colored matches golden console output', () async {
    // Process stdout is not a TTY, so colorize stays plain. This still locks
    // the template shape; ANSI bands need a real terminal.
    final result = await _runRender(
      executable: coverdeExecutablePath,
      projectDirPath: projectDirPath,
      report: 'coverde_value_colored',
    );
    final golden = File(
      p.join(goldensDirPath, 'coverde_value_colored.txt'),
    ).readAsStringSync();
    expect(
      _normalizeNewlines(result.stdout as String),
      _normalizeNewlines(golden),
    );
  });

  test('markdown matches golden markdown report', () async {
    await _runRender(
      executable: coverdeExecutablePath,
      projectDirPath: projectDirPath,
      report: 'markdown',
    );
    final actual = File(
      p.join(projectDirPath, 'build', 'markdown.md'),
    ).readAsStringSync();
    final golden = File(
      p.join(goldensDirPath, 'markdown.md'),
    ).readAsStringSync();
    expect(_normalizeNewlines(actual), _normalizeNewlines(golden));
  });
}

Future<ProcessResult> _runRender({
  required String executable,
  required String projectDirPath,
  required String report,
}) async {
  final result = await Process.run(
    executable,
    [
      'render',
      '--report',
      report,
      '--input',
      'coverage/lcov.info',
    ],
    workingDirectory: projectDirPath,
    runInShell: true,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    result.exitCode,
    0,
    reason: 'render $report failed:\n${result.stderr}\n${result.stdout}',
  );
  return result;
}

void _expectDirectoryMatchesGolden({
  required String actualDir,
  required String goldenDir,
}) {
  final actualRoot = Directory(actualDir);
  final goldenRoot = Directory(goldenDir);
  expect(actualRoot.existsSync(), isTrue, reason: 'missing $actualDir');
  expect(goldenRoot.existsSync(), isTrue, reason: 'missing $goldenDir');

  final actualFiles = _relativeFiles(actualRoot);
  final goldenFiles = _relativeFiles(goldenRoot);
  expect(actualFiles, orderedEquals(goldenFiles));

  for (final relative in goldenFiles) {
    final actualBytes = File(p.join(actualDir, relative)).readAsBytesSync();
    final goldenBytes = File(p.join(goldenDir, relative)).readAsBytesSync();
    if (_looksText(relative)) {
      expect(
        _normalizeNewlines(utf8.decode(actualBytes)),
        _normalizeNewlines(utf8.decode(goldenBytes)),
        reason: relative,
      );
    } else {
      expect(actualBytes, goldenBytes, reason: relative);
    }
  }
}

List<String> _relativeFiles(Directory root) {
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.normalize(p.relative(file.path, from: root.path)))
      .toList()
    ..sort();
  return files;
}

bool _looksText(String relativePath) {
  final lower = relativePath.toLowerCase();
  return lower.endsWith('.html') ||
      lower.endsWith('.css') ||
      lower.endsWith('.md') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.liquid');
}

/// Drop CR so Windows CRLF checkouts of Liquid templates still match goldens.
String _normalizeNewlines(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '');
