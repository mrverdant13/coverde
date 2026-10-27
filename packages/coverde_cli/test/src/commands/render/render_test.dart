import 'dart:convert';

import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:io/ansi.dart';
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
  group('appendTraceContent', () {
    test('closes an open final record and leaves a closed one alone', () {
      final open = StringBuffer();
      appendTraceContent(open, 'SF:a.dart\nDA:1,1');
      expect(open.toString(), 'SF:a.dart\nDA:1,1\nend_of_record\n');

      final closed = StringBuffer();
      appendTraceContent(closed, 'SF:a.dart\nDA:1,1\nend_of_record\n');
      expect(closed.toString(), 'SF:a.dart\nDA:1,1\nend_of_record\n');

      final empty = StringBuffer('keep');
      appendTraceContent(empty, '');
      expect(empty.toString(), 'keep');
    });
  });

  group('coverde render', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      packageVersionManager = _MockPackageVersionManager();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: packageVersionManager,
      );
    });

    tearDown(() {
      verifyNoMoreInteractions(logger);
    });

    test('renders the only report when --report is omitted', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(root, 'templates/summary.liquid', '''
{{ document.linesHit }}/{{ document.linesFound }} {{ variables["min-line-rate"] }}
''');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
DA:2,0
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.variableOption}',
          'min-line-rate=10',
          '--${RenderCommand.variableOption}',
          'min-line-rate=80',
        ]),
        getCurrentDirectory: () => root,
      );

      verify(() => logger.write(any(that: contains('1/2 80')))).called(1);
    });

    test('writes a console report to its destination file', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
    destination: out/summary.txt
''');
      _write(root, 'templates/summary.liquid', '{{ document.linesHit }}');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run(['render']),
        getCurrentDirectory: () => root,
      );

      expect(
        File('${root.path}/out/summary.txt').readAsStringSync(),
        contains('1'),
      );
    });

    test(
      'maps a console destination write error to a report failure',
      () async {
        final root = _project();
        addTearDown(() => root.deleteSync(recursive: true));
        Directory('${root.path}/out').createSync();
        _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
    destination: out
''');
        _write(root, 'templates/summary.liquid', 'ok');
        _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

        await expectLater(
          IOOverrides.runZoned(
            () => cmdRunner.run(['render']),
            getCurrentDirectory: () => root,
          ),
          throwsA(isA<CoverageReportDestinationFailure>()),
        );
      },
    );

    test('passes the terminal width into the template', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      debugReportColumns = 48;
      addTearDown(() => debugReportColumns = null);
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(root, 'templates/summary.liquid', '{{ columns }}');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run(['render']),
        getCurrentDirectory: () => root,
      );

      verify(() => logger.write('48')).called(1);
    });

    test('colors printed text and leaves a destination file plain', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      debugReportColor = true;
      addTearDown(() => debugReportColor = null);
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
  saved:
    type: console
    template: templates/summary.liquid
    destination: out/summary.txt
''');
      _write(
        root,
        'templates/summary.liquid',
        '{{ "hi" | colorize: "light_red" }}',
      );
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.reportOption}',
          'summary',
        ]),
        getCurrentDirectory: () => root,
      );
      verify(() => logger.write(wrapWith('hi', [lightRed]))).called(1);

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.reportOption}',
          'saved',
        ]),
        getCurrentDirectory: () => root,
      );
      expect(File('${root.path}/out/summary.txt').readAsStringSync(), 'hi');
    });

    test('passes coverage thresholds into the template', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
coverage:
  pkg-min: 90
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(root, 'templates/summary.liquid', '{{ thresholds["pkg-min"] }}');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run(['render']),
        getCurrentDirectory: () => root,
      );

      verify(() => logger.write('90')).called(1);
    });

    test('reads a config file and resolves paths from its directory', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'nested/coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
    destination: out/summary.txt
''');
      _write(
        root,
        'nested/templates/summary.liquid',
        '{{ document.linesHit }}',
      );
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.configOption}',
          'nested/coverde.yaml',
        ]),
        getCurrentDirectory: () => root,
      );

      expect(
        File('${root.path}/nested/out/summary.txt').readAsStringSync(),
        '1',
      );
    });

    test('merges repeated inputs and keeps the latest trace time', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(
        root,
        'templates/summary.liquid',
        '{{ document.linesHit }}/{{ document.linesFound }} {{ document.traceModifiedAt }}',
      );
      _write(root, 'coverage/one.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');
      _write(root, 'coverage/two.info', '''
SF:lib/b.dart
DA:1,0
end_of_record
''');
      File(
        '${root.path}/coverage/one.info',
      ).setLastModifiedSync(DateTime.utc(2020));
      final newer = File('${root.path}/coverage/two.info')
        ..setLastModifiedSync(DateTime.utc(2024, 1, 2, 3, 4, 5));

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.inputOption}',
          'coverage/one.info',
          '--${RenderCommand.inputOption}',
          'coverage/two.info',
        ]),
        getCurrentDirectory: () => root,
      );

      verify(
        () => logger.write(
          any(
            that: contains('1/2 ${newer.lastModifiedSync().toIso8601String()}'),
          ),
        ),
      ).called(1);
    });

    test('closes an open record before the next input trace', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(
        root,
        'templates/summary.liquid',
        '{{ document.linesHit }}/{{ document.linesFound }}',
      );
      _write(root, 'coverage/one.info', '''
SF:lib/a.dart
DA:1,1
''');
      _write(root, 'coverage/two.info', '''
SF:lib/b.dart
DA:1,0
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.inputOption}',
          'coverage/one.info',
          '--${RenderCommand.inputOption}',
          'coverage/two.info',
        ]),
        getCurrentDirectory: () => root,
      );

      verify(() => logger.write(any(that: contains('1/2')))).called(1);
    });

    test('fails when one of several trace files is missing', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(root, 'templates/summary.liquid', 'x');
      _write(root, 'coverage/one.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');
      final missing = p.normalize(
        p.join(root.path, 'coverage', 'missing.info'),
      );

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run([
            'render',
            '--${RenderCommand.inputOption}',
            'coverage/one.info',
            '--${RenderCommand.inputOption}',
            'coverage/missing.info',
          ]),
          throwsA(
            isA<CoverdeRenderTraceFileNotFoundFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              'No trace file found at `$missing`.',
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('writes a files report into the configured destination', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  pages:
    type: files
    destination: out/
    root:
      template: templates/page.liquid
      path: index.html
''');
      _write(root, 'templates/page.liquid', '{{ document.linesHit }}');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.reportOption}',
          'pages',
        ]),
        getCurrentDirectory: () => root,
      );

      expect(File('${root.path}/out/index.html').readAsStringSync(), '1');
    });

    test('fails when coverde.yaml defines more than one report', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
  pages:
    type: files
    destination: out/
    root:
      template: templates/page.liquid
      path: index.html
''');
      _write(root, 'coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
end_of_record
''');

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(['render']),
          throwsA(
            isA<CoverageReportDefinitionFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains('Pass --report'),
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('lists defined reports when the requested name is missing', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run([
            'render',
            '--${RenderCommand.reportOption}',
            'missing',
          ]),
          throwsA(
            isA<UnknownCoverageReportFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains('summary'),
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('fails when no reports are defined', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(['render']),
          throwsA(
            isA<CoverageReportDefinitionFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains('No reports are defined'),
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('fails when a variable is not name=value', () async {
      expect(
        () => cmdRunner.run([
          'render',
          '--${RenderCommand.variableOption}',
          'min-line-rate',
        ]),
        throwsA(
          isA<CoverdeRenderInvalidVariableFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('name=value'),
          ),
        ),
      );
    });

    test('fails when the trace file is missing', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');

      final traceFilePath = p.normalize(
        p.join(root.path, 'coverage', 'lcov.info'),
      );

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(['render']),
          throwsA(
            isA<CoverdeRenderTraceFileNotFoundFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              'No trace file found at `$traceFilePath`.',
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('fails when the trace file is empty', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      _write(root, 'coverage/lcov.info', '');

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(['render']),
          throwsA(
            isA<CoverdeRenderEmptyTraceFileFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains('No coverage data found'),
            ),
          ),
        );
      }, getCurrentDirectory: () => root);
    });

    test('fails when the trace file cannot be read', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      _write(root, 'coverde.yaml', '''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''');
      final traceFile = File(p.join(root.path, 'coverage', 'lcov.info'))
        ..createSync(recursive: true);

      final yaml = File('${root.path}/coverde.yaml').readAsStringSync();

      await IOOverrides.runZoned(
        () async {
          expect(
            () => cmdRunner.run(['render']),
            throwsA(
              isA<CoverdeRenderTraceFileReadFailure>().having(
                (failure) => failure.readableMessage,
                'readableMessage',
                contains('denied'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => root,
        createFile: (path) {
          if (p.equals(path, traceFile.path)) {
            return _ThrowingFile(
              path: path,
              readAsStringSync: () => throw const FileSystemException('denied'),
              openRead: () => throw const FileSystemException('denied'),
            );
          }
          if (p.basename(path) == 'coverde.yaml') {
            return _ThrowingFile(path: path, readAsStringSync: () => yaml);
          }
          throw UnsupportedError(path);
        },
      );
    });

    test('fails when coverde.yaml cannot be read', () async {
      final root = _project();
      addTearDown(() => root.deleteSync(recursive: true));
      final config = File('${root.path}/coverde.yaml')..createSync();

      await IOOverrides.runZoned(
        () async {
          expect(
            () => cmdRunner.run(['render']),
            throwsA(
              isA<CoverdeRenderConfigFileReadFailure>().having(
                (failure) => failure.readableMessage,
                'readableMessage',
                contains('denied'),
              ),
            ),
          );
        },
        getCurrentDirectory: () => root,
        createFile: (path) {
          if (p.equals(path, config.path)) {
            return _ThrowingFile(
              path: path,
              readAsStringSync: () => throw const FileSystemException('denied'),
            );
          }
          throw UnsupportedError(path);
        },
      );
    });
  });
}

Directory _project() {
  return Directory.systemTemp.createTempSync('coverde_render_');
}

void _write(Directory root, String relativePath, String contents) {
  final file = File(p.join(root.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

final class _ThrowingFile extends Fake implements File {
  _ThrowingFile({
    required this.path,
    required String Function() readAsStringSync,
    Stream<List<int>> Function()? openRead,
  }) : _readAsStringSync = readAsStringSync,
       _openRead = openRead;

  @override
  final String path;

  final String Function() _readAsStringSync;
  final Stream<List<int>> Function()? _openRead;

  @override
  String readAsStringSync({Encoding encoding = utf8}) => _readAsStringSync();

  @override
  DateTime lastModifiedSync() => DateTime.utc(2026);

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    final openRead = _openRead;
    if (openRead == null) return const Stream.empty();
    return openRead();
  }
}
