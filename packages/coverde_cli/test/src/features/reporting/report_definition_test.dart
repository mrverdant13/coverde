import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/templates/parse_report_definitions.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:test/test.dart';

void main() {
  group('parseReportDefinitions', () {
    test('rejects destination on a console report', () {
      expect(
        () => parseReportDefinitions('''
reports:
  summary:
    type: console
    template: templates/summary.liquid
    destination: coverage/
''', baseDirectory: '/config'),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('cannot set `destination`'),
          ),
        ),
      );
    });

    test('requires a destination and a slot for a files report', () {
      expect(
        () => parseReportDefinitions('''
reports:
  pages:
    type: files
    file:
      template: templates/file.liquid
      path: "{{ file.path }}.html"
''', baseDirectory: '/config'),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('requires `destination`'),
          ),
        ),
      );
      expect(
        () => parseReportDefinitions('''
reports:
  pages:
    type: files
    destination: coverage/
''', baseDirectory: '/config'),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('requires `root`, `directory`, or `file`'),
          ),
        ),
      );
    });

    test('lists defined names when the requested report is missing', () {
      final reports = parseReportDefinitions('''
reports:
  summary:
    type: console
    template: templates/summary.liquid
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
''', baseDirectory: '/config');

      expect(
        () => resolveReportDefinition(
          reports: reports,
          reportName: 'missing',
          configPath: 'coverde.yaml',
        ),
        throwsA(
          isA<UnknownCoverageReportFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            'Unknown report `missing` in `coverde.yaml`.\n'
                'Available reports: pages, summary.',
          ),
        ),
      );
    });

    test('reads an empty report map when reports are absent', () {
      expect(
        parseReportDefinitions(
          'coverage:\n  pkg-min: 100\n',
          baseDirectory: '.',
        ),
        isEmpty,
      );
      expect(parseReportDefinitions('', baseDirectory: '.'), isEmpty);
    });

    test('selects the only report when no name is given', () {
      final reports = parseReportDefinitions('''
reports:
  summary:
    type: console
    template: templates/summary.liquid
''', baseDirectory: '/config');

      expect(
        resolveReportDefinition(
          reports: reports,
          reportName: null,
          configPath: 'coverde.yaml',
        ),
        isA<ConsoleReportDefinition>(),
      );
      final pages = parseReportDefinitions('''
reports:
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
    assets:
      - from: templates/report.css
        to: report.css
''', baseDirectory: '/config');
      final definition = pages['pages']! as FilesReportDefinition;
      expect(definition.assets.single.from, 'templates/report.css');
      expect(definition.assets.single.to, 'report.css');
    });

    test('rejects an ambiguous or empty report choice', () {
      expect(
        () => resolveReportDefinition(
          reports: const {},
          reportName: null,
          configPath: 'coverde.yaml',
        ),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('No reports are defined'),
          ),
        ),
      );
      final reports = parseReportDefinitions('''
reports:
  summary:
    type: console
    template: templates/summary.liquid
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
''', baseDirectory: '/config');
      expect(
        () => resolveReportDefinition(
          reports: reports,
          reportName: null,
          configPath: 'coverde.yaml',
        ),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('more than one report'),
          ),
        ),
      );
    });

    test('rejects invalid report configuration', () {
      void rejects(String source, String message) {
        expect(
          () => parseReportDefinitions(source, baseDirectory: '/config'),
          throwsA(
            isA<CoverageReportDefinitionFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains(message),
            ),
          ),
          reason: message,
        );
      }

      rejects('- just-a-list\n', 'must be a YAML map');
      rejects('reports: [summary]\n', '`reports` must be a map');
      rejects('reports:\n  ? \n', 'must be non-empty strings');
      rejects('reports:\n  summary: text\n', 'must be a map');
      rejects('reports:\n  summary: {}\n', 'missing a `type`');
      rejects('reports:\n  summary:\n    type: json\n', 'unknown type `json`');
      rejects('''
reports:
  summary:
    type: console
    template: templates/summary.liquid
    extra: 1
''', 'unknown key `extra`');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    root: index.html
''', 'slot `root` must be a map');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
      includeSource: true
''', 'unknown key `includeSource`');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    file:
      template: templates/file.liquid
      path: index.html
      includeSource: yes
''', '`includeSource` must be a boolean');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
    assets: report.css
''', '`assets` must be a list');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
    assets:
      - report.css
''', 'asset 1 must be a map');
      rejects('''
reports:
  pages:
    type: files
    destination: coverage/
    root:
      template: templates/root.liquid
      path: index.html
    assets:
      - from: report.css
        to: report.css
        extra: 1
''', 'unknown key `extra`');
      rejects('''
reports:
  summary:
    type: console
    template: "  "
''', 'requires `template`');
      rejects('reports: [\n', 'Invalid report configuration');
    });

    test('keeps includeSource on a file slot', () {
      final reports = parseReportDefinitions('''
reports:
  pages:
    type: files
    destination: coverage/
    file:
      template: templates/file.liquid
      path: "{{ file.path }}.html"
      includeSource: true
''', baseDirectory: '/config');

      final definition = reports['pages']! as FilesReportDefinition;
      expect(definition.file!.includeSource, isTrue);
      expect(definition.file!.template, 'templates/file.liquid');
      expect(definition.file!.path, '{{ file.path }}.html');
    });

    test('names no available reports when none are defined', () {
      expect(
        () => resolveReportDefinition(
          reports: const {},
          reportName: 'missing',
          configPath: 'coverde.yaml',
        ),
        throwsA(
          isA<UnknownCoverageReportFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            'Unknown report `missing` in `coverde.yaml`.\n'
                'Available reports: none.',
          ),
        ),
      );
    });
  });
}
