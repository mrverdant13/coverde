import 'package:coverde/src/commands/coverde_command_runner.dart';
import 'package:coverde/src/commands/render/render.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory project;
  late String executable;

  setUp(() {
    project = Directory.systemTemp.createTempSync('coverde_render_exit_');
    executable = _executable();
  });

  tearDown(() {
    if (!Platform.isWindows && project.existsSync()) {
      Process.runSync('chmod', ['-R', 'u+rwx', project.path]);
    }
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  test('unknown report exits with usage', () async {
    _write(project, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/page.liquid
''');

    final result = await _render(project, executable, report: 'missing');

    expect(result.exitCode, ExitCode.usage.code, reason: _output(result));
  });

  test('an ambiguous report exits with data', () async {
    _write(project, 'coverde.yaml', '''
reports:
  one:
    type: console
    template: templates/page.liquid
  two:
    type: console
    template: templates/page.liquid
''');

    final result = await _render(project, executable);

    expect(result.exitCode, ExitCode.data.code, reason: _output(result));
  });

  test('a path outside the destination exits with data', () async {
    _page(project);
    _trace(project);

    final result = await _render(project, executable);

    expect(result.exitCode, ExitCode.data.code, reason: _output(result));
  });

  test('an unknown template variable exits with data', () async {
    _write(project, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/page.liquid
''');
    _write(project, 'templates/page.liquid', '{{ nope }}');
    _trace(project);

    final result = await _render(project, executable);

    expect(result.exitCode, ExitCode.data.code, reason: _output(result));
  });

  test('an unreadable source file exits with an I/O error', () async {
    final source = File(p.join(project.path, 'lib', 'a.dart'));
    _write(project, 'lib/a.dart', 'void main() {}\n');
    _denyRead(source);
    _write(project, 'coverde.yaml', '''
reports:
  pages:
    type: files
    destination: out
    file:
      template: templates/file.liquid
      path: page.html
      includeSource: true
''');
    _write(project, 'templates/file.liquid', 'x');
    _trace(project, sourcePath: source.path);

    final result = await _render(project, executable);

    expect(result.exitCode, ExitCode.ioError.code, reason: _output(result));
  });

  test('a destination that is a file exits with an I/O error', () async {
    _write(project, 'coverde.yaml', '''
reports:
  pages:
    type: files
    destination: not-a-directory
    root:
      template: templates/page.liquid
      path: index.html
''');
    _write(project, 'templates/page.liquid', 'x');
    _write(project, 'not-a-directory', 'file');
    _trace(project);

    final result = await _render(project, executable);

    expect(result.exitCode, ExitCode.ioError.code, reason: _output(result));
  });
}

void _page(Directory project) {
  _write(project, 'coverde.yaml', '''
reports:
  pages:
    type: files
    destination: out
    root:
      template: templates/page.liquid
      path: "../out.html"
''');
  _write(project, 'templates/page.liquid', 'x');
}

void _trace(Directory project, {String sourcePath = 'lib/a.dart'}) {
  _write(project, 'coverage/lcov.info', '''
SF:$sourcePath
DA:1,1
end_of_record
''');
}

Future<ProcessResult> _render(
  Directory project,
  String executable, {
  String? report,
}) {
  return Process.run(Platform.resolvedExecutable, [
    executable,
    '--${CoverdeCommandRunner.updateCheckOptionName}=disabled',
    'render',
    if (report != null) ...['--${RenderCommand.reportOption}', report],
  ], workingDirectory: project.path);
}

String _executable() {
  final candidates = [
    p.join(Directory.current.path, 'bin', 'coverde.dart'),
    p.join(
      Directory.current.path,
      'packages',
      'coverde_cli',
      'bin',
      'coverde.dart',
    ),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return p.normalize(candidate);
  }
  fail('Could not find bin/coverde.dart from ${Directory.current.path}.');
}

void _denyRead(File file) {
  final result = Platform.isWindows
      ? Process.runSync('icacls', [file.path, '/deny', 'Everyone:(R)'])
      : Process.runSync('chmod', ['a-r', file.path]);
  if (result.exitCode != 0) {
    fail('Could not remove read access.\n${result.stdout}\n${result.stderr}');
  }
  expect(
    file.readAsLinesSync,
    throwsA(isA<FileSystemException>()),
    reason: 'The source file is still readable.',
  );
}

void _write(Directory root, String relativePath, String contents) {
  final file = File(p.join(root.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

String _output(ProcessResult result) => '${result.stdout}\n${result.stderr}';
