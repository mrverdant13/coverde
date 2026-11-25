import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/commands/report/terminal_report.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
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
  group('coverde report custom', () {
    late Logger logger;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: _MockPackageVersionManager(),
      );
    });

    test('help without a name lists the shared flags', () async {
      final directory = Directory.systemTemp.createTempSync('coverde-custom-');
      addTearDown(() => directory.deleteSync(recursive: true));

      await IOOverrides.runZoned(() async {
        await cmdRunner.run(['report', 'custom', '--help']);
      }, getCurrentDirectory: () => directory);

      verify(
        () => logger.write(
          any(
            that: allOf(
              contains('--${ReportCustomCommand.inputOption}'),
              contains('--${ReportCustomCommand.configOption}'),
              contains('[name]'),
              isNot(contains('--region')),
            ),
          ),
        ),
      ).called(1);
    });

    test('help for a report lists its options', () async {
      final directory = _project(yaml: _consoleYaml, template: 'x');

      await IOOverrides.runZoned(() async {
        await cmdRunner.run(['report', 'custom', 'summary', '--help']);
      }, getCurrentDirectory: () => directory);

      verify(
        () => logger.write(
          any(that: allOf(contains('--region'), contains('Allowed: us, eu'))),
        ),
      ).called(1);
    });

    test('passes declared options in either flag order and keeps the last '
        'value', () async {
      final directory = _project(
        yaml: _consoleYaml,
        template: '{{ color }}{{ variables.region }}{{ columns }}',
      );
      addTearDown(() {
        debugReportColumns = null;
        debugReportColor = null;
      });
      debugReportColumns = 48;
      debugReportColor = true;

      await IOOverrides.runZoned(() async {
        await cmdRunner.run([
          'report',
          'custom',
          '--region',
          'eu',
          '--config',
          'coverde.yaml',
          'summary',
        ]);
        verify(() => logger.write('true${'eu'}48')).called(1);

        await _FakeCoverdeCommandRunner(
          logger: logger,
          packageVersionManager: _MockPackageVersionManager(),
        ).run([
          'r',
          'custom',
          '--config=coverde.yaml',
          'summary',
          '--region',
          'eu',
          '--region=us',
        ]);
        verify(() => logger.write('true${'us'}48')).called(1);
      }, getCurrentDirectory: () => directory);
    });

    test('writes a files report without color and merges traces', () async {
      final directory = _project(
        yaml: '''
reports:
  pages:
    type: files
    destination: out
    root:
      template: page.liquid
      path: index.html
''',
        template: '''
{{ color }}
{% for file in document.files %}{{ file.path }}
{% endfor %}
''',
      );
      final other = File(p.join(directory.path, 'other.lcov.info'))
        ..writeAsStringSync('SF:lib/b.dart\nDA:1,1\nend_of_record\n');
      debugReportColor = true;
      addTearDown(() => debugReportColor = null);

      await IOOverrides.runZoned(() async {
        await cmdRunner.run([
          'report',
          'custom',
          'pages',
          '--${ReportCustomCommand.inputOption}',
          'coverage/lcov.info',
          '--${ReportCustomCommand.inputOption}',
          other.path,
        ]);
      }, getCurrentDirectory: () => directory);

      final page = File(
        p.join(directory.path, 'out', 'index.html'),
      ).readAsStringSync();
      expect(page, contains('false'));
      expect(page, contains('lib/a.dart'));
      expect(page, contains('lib/b.dart'));
    });

    test('writes a console report to a file', () async {
      final directory = _project(
        yaml: '''
reports:
  summary:
    type: console
    template: page.liquid
    destination: out/summary.txt
''',
        template: 'saved',
      );

      await IOOverrides.runZoned(() async {
        await cmdRunner.run(['report', 'custom', 'summary']);
      }, getCurrentDirectory: () => directory);

      expect(
        File(p.join(directory.path, 'out', 'summary.txt')).readAsStringSync(),
        contains('saved'),
      );
    });

    test(
      'rejects a missing name, an extra argument, and a bad option',
      () async {
        final directory = _project(yaml: _consoleYaml, template: 'x');

        await IOOverrides.runZoned(() async {
          expect(
            () => cmdRunner.run(['report', 'custom']),
            throwsA(isA<CoverdeReportMissingReportNameFailure>()),
          );
          expect(
            () => cmdRunner.run(['report', 'custom', 'summary', 'extra']),
            throwsA(
              isA<CoverdeReportUnexpectedArgumentFailure>().having(
                (failure) => failure.argument,
                'argument',
                'extra',
              ),
            ),
          );
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              'summary',
              '--region',
              'mx',
            ]),
            throwsA(
              isA<UsageException>().having(
                (error) => error.message,
                'message',
                contains('for option "--region"'),
              ),
            ),
          );
          expect(
            () => cmdRunner.run(['report', 'custom', 'summary', '-x']),
            throwsA(isA<UsageException>()),
          );
        }, getCurrentDirectory: () => directory);
      },
    );

    test(
      'rejects a missing config, a directory, and an unknown report',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'coverde-custom-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final missing = p.join(directory.path, 'missing.yaml');
        final configDir = Directory(p.join(directory.path, 'dir.yaml'))
          ..createSync();

        await IOOverrides.runZoned(() async {
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              'summary',
              '--${ReportCustomCommand.configOption}',
              missing,
            ]),
            throwsA(
              isA<CoverdeReportConfigFileNotFoundFailure>().having(
                (failure) => failure.readableMessage,
                'readableMessage',
                'Config file at `$missing` is not a file.',
              ),
            ),
          );
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              '--${ReportCustomCommand.configOption}',
              configDir.path,
              'summary',
            ]),
            throwsA(isA<CoverdeReportConfigFileNotFoundFailure>()),
          );
          _writeConfig(directory, _consoleYaml);
          expect(
            () => cmdRunner.run(['report', 'custom', 'missing']),
            throwsA(isA<UnknownCoverageReportFailure>()),
          );
        }, getCurrentDirectory: () => directory);
      },
    );

    test(
      'rejects invalid yaml, an unreadable config, and a bad trace',
      () async {
        final directory = _project(yaml: 'reports: [', template: 'x');
        await IOOverrides.runZoned(() async {
          expect(
            () => cmdRunner.run(['report', 'custom', 'summary']),
            throwsA(isA<CoverageReportDefinitionFailure>()),
          );
        }, getCurrentDirectory: () => directory);

        final unreadable = _project(yaml: _consoleYaml, template: 'x');
        final config = File(p.join(unreadable.path, 'coverde.yaml'));
        _denyRead(config);
        addTearDown(() => _allowRead(config));
        await IOOverrides.runZoned(() async {
          expect(
            () => cmdRunner.run(['report', 'custom', 'summary']),
            throwsA(
              isA<CoverdeReportConfigFileReadFailure>().having(
                (failure) => failure.readableMessage,
                'readableMessage',
                contains('Failed to read config file'),
              ),
            ),
          );
        }, getCurrentDirectory: () => unreadable);

        final traces = _project(yaml: _consoleYaml, template: 'x');
        await IOOverrides.runZoned(() async {
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              'summary',
              '--${ReportCustomCommand.inputOption}',
              p.join(traces.path, 'missing.lcov.info'),
            ]),
            throwsA(isA<CoverdeReportTraceFileNotFoundFailure>()),
          );
          File(p.join(traces.path, 'empty.lcov.info')).writeAsStringSync('\n');
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              'summary',
              '-i${'empty.lcov.info'}',
            ]),
            throwsA(isA<CoverdeReportEmptyTraceFileFailure>()),
          );
          final blocked = File(p.join(traces.path, 'blocked.lcov.info'))
            ..writeAsStringSync('SF:lib/a.dart\nDA:1,1\nend_of_record\n');
          _denyRead(blocked);
          addTearDown(() => _allowRead(blocked));
          expect(
            () => cmdRunner.run([
              'report',
              'custom',
              'summary',
              '-i',
              blocked.path,
            ]),
            throwsA(isA<CoverdeReportTraceFileReadFailure>()),
          );
        }, getCurrentDirectory: () => traces);
      },
    );

    test('rejects a console file whose parent cannot be created', () async {
      final directory = _project(
        yaml: '''
reports:
  summary:
    type: console
    template: page.liquid
    destination: blocked/summary.txt
''',
        template: 'saved',
      );
      File(
        p.join(directory.path, 'blocked'),
      ).writeAsStringSync('not a directory');

      await IOOverrides.runZoned(() async {
        expect(
          () => cmdRunner.run(['report', 'custom', 'summary']),
          throwsA(isA<CoverageReportDestinationFailure>()),
        );
      }, getCurrentDirectory: () => directory);
    });

    test('accepts a parent option before the command', () async {
      final directory = _project(yaml: _consoleYaml, template: 'ok');

      await IOOverrides.runZoned(() async {
        await cmdRunner.run([
          '--${CoverdeCommandRunner.updateCheckOptionName}',
          UpdateCheckMode.disabled.identifier,
          'report',
          'custom',
          'summary',
        ]);
      }, getCurrentDirectory: () => directory);

      verify(() => logger.write(any(that: contains('ok')))).called(1);
    });
  });
}

const _consoleYaml = '''
reports:
  summary:
    type: console
    template: page.liquid
    options:
      region:
        default: us
        allowed: [us, eu]
      title:
        default: Coverage
''';

Directory _project({required String yaml, required String template}) {
  final directory = Directory.systemTemp.createTempSync('coverde-custom-');
  addTearDown(() => directory.deleteSync(recursive: true));
  _writeConfig(directory, yaml);
  File(p.join(directory.path, 'page.liquid')).writeAsStringSync(template);
  File(p.join(directory.path, 'coverage', 'lcov.info'))
    ..createSync(recursive: true)
    ..writeAsStringSync('SF:lib/a.dart\nDA:1,1\nend_of_record\n');
  return directory;
}

void _writeConfig(Directory directory, String yaml) {
  File(p.join(directory.path, 'coverde.yaml')).writeAsStringSync(yaml);
}

void _denyRead(File file) {
  final result = Platform.isWindows
      ? Process.runSync('icacls', [file.path, '/deny', 'Everyone:(R)'])
      : Process.runSync('chmod', ['a-r', file.path]);
  if (result.exitCode != 0) {
    fail('Could not remove read access.\n${result.stdout}\n${result.stderr}');
  }
}

void _allowRead(File file) {
  if (!file.existsSync()) return;
  if (Platform.isWindows) {
    Process.runSync('icacls', [file.path, '/remove:d', 'Everyone']);
    return;
  }
  Process.runSync('chmod', ['u+r', file.path]);
}
