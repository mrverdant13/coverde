import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:coverde/src/features/reporting/templates/strict_template_map.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$TemplateCoverageReporter', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('coverde_template_report_');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('prints a console summary with compact uncovered ranges', () async {
      _write(root, 'templates/summary.liquid', '''
{%- assign minimum = variables["min-line-rate"] | plus: 0 -%}
Line coverage: {{ document.lineRate | round: 2 }}% ({{ document.linesHit }}/{{ document.linesFound }})
{%- if document.branchRate == null %}
Branches: n/a
{%- else %}
Branches: {{ document.branchRate | round: 2 }}%
{%- endif %}
{%- for file in document.files %}
{%- assign missed = file.lines | where: "hits", 0 | map: "number" | compact_ranges -%}
{{ file.path }} {{ missed }}
{%- endfor %}
{%- if document.lineRate < minimum %}
Below {{ minimum }}%.
{%- endif -%}
''');
      final sink = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(sink),
        variables: const {'min-line-rate': '80'},
        trace: '''
SF:lib/a.dart
DA:1,1
DA:3,0
DA:4,0
DA:6,0
end_of_record
''',
      );

      expect(sink.toString(), contains('Branches: n/a'));
      expect(sink.toString(), contains('lib/a.dart 3-4, 6'));
      expect(sink.toString(), contains('Below 80%.'));
    });

    test(
      'nests directories in one file and leaves output paths empty',
      () async {
        _write(root, 'templates/pr-comment.liquid', '''
## Coverage {{ document.lineRate | round: 2 }}%
{% render 'templates/folder.liquid', node: root %}
''');
        _write(root, 'templates/folder.liquid', '''
<details>
<summary>{{ node.path | default: "All files" }} {{ node.lineRate | round: 2 }}%</summary>
{%- for child in node.directories %}
{% render 'templates/folder.liquid', node: child %}
{%- endfor %}
{%- for file in node.files %}
<details>
<summary>{{ file.path }}</summary>
{%- assign missed = file.lines | where: "hits", 0 | map: "number" | compact_ranges -%}
Uncovered lines: {{ missed | default: "none" }}
output: {{ file.outputPath }}
</details>
{%- endfor %}
</details>
''');
        final destination = Directory('${root.path}/out');

        await _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            root: const ReportSlot(
              template: 'templates/pr-comment.liquid',
              path: 'comment.md',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          trace: '''
SF:lib/a.dart
DA:1,1
DA:2,0
DA:3,0
end_of_record
SF:lib/src/b.dart
DA:1,1
end_of_record
''',
        );

        final comment =
            File('${destination.path}/comment.md').readAsStringSync();
        expect(comment, contains('<summary>lib'));
        expect(comment, contains('<summary>lib/src'));
        expect(comment, contains('Uncovered lines: 2-3'));
        expect(comment, contains('Uncovered lines: none'));
        expect(comment, contains('output: \n'));
      },
    );

    test('links directory pages with output paths and source lines', () async {
      _write(root, 'templates/report.css', 'body{}\n');
      _write(root, 'templates/directory.liquid', '''
{%- assign node = directory | default: root -%}
<link rel="stylesheet" href="{{ pathToRoot }}report.css">
<h1>{{ node.path }}</h1>
{%- for child in node.directories %}
<a href="{{ pathToRoot }}{{ child.outputPath }}">{{ child.path }}</a>
{%- endfor %}
{%- for child in node.files %}
<a href="{{ pathToRoot }}{{ child.outputPath }}">{{ child.path }}</a>
{%- endfor %}
''');
      _write(root, 'templates/file.liquid', '''
<link rel="stylesheet" href="{{ pathToRoot }}report.css">
<h1>{{ file.path }}</h1>
{%- for line in file.lines %}
{{ line.number }}|{{ line.hits }}|{{ line.source }}
{%- endfor %}
''');
      final destination = Directory('${root.path}/html');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/directory.liquid',
            path: 'index.html',
          ),
          directory: const ReportSlot(
            template: 'templates/directory.liquid',
            path: '{{ directory.path }}/index.html',
          ),
          file: const ReportSlot(
            template: 'templates/file.liquid',
            path: '{{ file.path }}.html',
            includeSource: true,
          ),
          assets: const [
            ReportAsset(from: 'templates/report.css', to: 'report.css'),
          ],
        ),
        destination: DirectoryReportDestination(destination),
        sources: _MapSourceReader({
          'lib/src/app.dart': const ['class App {', '  return;', '}'],
        }),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/src/app.dart
DA:2,3
end_of_record
''',
      );

      final index = File('${destination.path}/index.html').readAsStringSync();
      expect(index, contains('href="report.css"'));
      expect(index, contains('href="lib/src/index.html"'));
      expect(index, contains('href="lib/a.dart.html"'));
      final directoryPage =
          File('${destination.path}/lib/src/index.html').readAsStringSync();
      expect(directoryPage, contains('href="../../report.css"'));
      expect(directoryPage, contains('href="../../lib/src/app.dart.html"'));
      final filePage =
          File('${destination.path}/lib/src/app.dart.html').readAsStringSync();
      expect(filePage, contains('1||class App {'));
      expect(filePage, contains('2|3|  return;'));
      expect(filePage, contains('3||}'));
      expect(
        File('${destination.path}/report.css').readAsStringSync(),
        'body{}\n',
      );
    });

    test(
      'uses the directory template for the root when root is omitted',
      () async {
        _write(
          root,
          'templates/directory.liquid',
          'dir {{ directory.path }}\n',
        );
        final destination = Directory('${root.path}/out');

        await _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            directory: const ReportSlot(
              template: 'templates/directory.liquid',
              path: '{{ directory.path }}/index.html',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,1
end_of_record
''',
        );

        expect(
          File('${destination.path}/lib/index.html').readAsStringSync(),
          contains('dir lib'),
        );
      },
    );

    test(
      'keeps a missing source render successful with null source text',
      () async {
        _write(
          root,
          'templates/file.liquid',
          '{%- for line in file.lines %}{{ line.source }}{%- endfor %}\n',
        );
        final destination = Directory('${root.path}/out');

        await _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            file: const ReportSlot(
              template: 'templates/file.liquid',
              path: '{{ file.path }}.html',
              includeSource: true,
            ),
          ),
          destination: DirectoryReportDestination(destination),
          sources: _MapSourceReader(const {}),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        );

        expect(
          File('${destination.path}/lib/a.dart.html').readAsStringSync().trim(),
          isEmpty,
        );
      },
    );

    test('rejects a source path that escapes the destination', () async {
      _write(root, 'templates/file.liquid', 'x\n');
      final destination = Directory('${root.path}/out');

      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            file: const ReportSlot(
              template: 'templates/file.liquid',
              path: '{{ file.path }}.html',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          trace: '''
SF:../secret.dart
DA:1,1
end_of_record
''',
        ),
        throwsA(isA<CoverageReportPathFailure>()),
      );
    });

    test('rejects two slots that write the same path', () async {
      _write(root, 'templates/page.liquid', 'x\n');
      final destination = Directory('${root.path}/out');

      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            root: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'index.html',
            ),
            file: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'index.html',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        ),
        throwsA(
          isA<CoverageReportPathFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('index.html'),
          ),
        ),
      );
    });

    test('rejects an unknown template variable', () async {
      _write(root, 'templates/summary.liquid', '{{ nope }}\n');
      final sink = StringBuffer();

      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        ),
        throwsA(
          isA<CoverageTemplateRenderFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('nope'),
          ),
        ),
      );
    });

    test('rejects a missing template and a template that cannot be read', () {
      final sink = StringBuffer();
      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/missing.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: _lineTrace,
        ),
        throwsA(
          isA<CoverageTemplateRenderFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('was not found'),
          ),
        ),
      );

      _write(root, 'templates/summary.liquid', '{{ document.lineRate }}');
      final file = _MockFile();
      when(file.existsSync).thenReturn(true);
      when(
        file.readAsStringSync,
      ).thenThrow(const FileSystemException('denied'));
      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: _lineTrace,
          open: (_) => file,
        ),
        throwsA(
          isA<CoverageTemplateRenderFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('denied'),
          ),
        ),
      );
    });

    test('rejects the wrong destination for a report', () {
      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: DirectoryReportDestination(
            Directory('${root.path}/out'),
          ),
          trace: _lineTrace,
        ),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('console sink'),
          ),
        ),
      );
      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: '${root.path}/out',
            root: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'index.html',
            ),
          ),
          destination: ConsoleReportDestination(StringBuffer()),
          trace: _lineTrace,
        ),
        throwsA(
          isA<CoverageReportDefinitionFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('directory'),
          ),
        ),
      );
    });

    test('rejects paths that are empty, absolute, or not a file', () async {
      _write(root, 'templates/page.liquid', 'x\n');
      final destination = Directory('${root.path}/out');
      for (final path in ['', 'index/', '/tmp/out.html', '.']) {
        expect(
          () => _render(
            root: root,
            definition: FilesReportDefinition(
              destination: destination.path,
              root: ReportSlot(template: 'templates/page.liquid', path: path),
            ),
            destination: DirectoryReportDestination(destination),
            trace: _lineTrace,
          ),
          throwsA(isA<CoverageReportPathFailure>()),
          reason: path,
        );
      }
    });

    test('rejects an asset that collides or cannot be copied', () async {
      _write(root, 'templates/page.liquid', 'x\n');
      _write(root, 'templates/report.css', 'body{}\n');
      final destination = Directory('${root.path}/out');
      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            root: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'index.html',
            ),
            assets: const [
              ReportAsset(from: 'templates/report.css', to: 'index.html'),
            ],
          ),
          destination: DirectoryReportDestination(destination),
          trace: _lineTrace,
        ),
        throwsA(
          isA<CoverageReportPathFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('index.html'),
          ),
        ),
      );
      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            root: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'index.html',
            ),
            assets: const [
              ReportAsset(from: 'templates/missing.css', to: 'report.css'),
            ],
          ),
          destination: DirectoryReportDestination(destination),
          trace: _lineTrace,
        ),
        throwsA(isA<CoverageReportDestinationFailure>()),
      );
    });

    test('fails when the output parent is not a directory', () async {
      _write(root, 'templates/page.liquid', 'x\n');
      final destination = Directory('${root.path}/out')..createSync();
      File('${destination.path}/nested').writeAsStringSync('not a directory');

      expect(
        () => _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            root: const ReportSlot(
              template: 'templates/page.liquid',
              path: 'nested/index.html',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          trace: _lineTrace,
        ),
        throwsA(isA<CoverageReportDestinationFailure>()),
      );
    });

    test('rejects an unknown property and a broken template', () async {
      _write(root, 'templates/summary.liquid', '{{ document.missing }}');
      final sink = StringBuffer();
      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: _lineTrace,
        ),
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );

      _write(root, 'templates/summary.liquid', '{% if %}');
      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: _lineTrace,
        ),
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );
    });

    test('renders grouped checks and indexed file access', () async {
      _write(root, 'templates/summary.liquid', '''
{%- if not (document.lineRate) -%}
no
{%- else -%}
{{ document.files[0].path }}
{%- endif -%}
''');
      final sink = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(sink),
        trace: _lineTrace,
      );

      expect(sink.toString(), contains('lib/a.dart'));
    });

    test('fails when a partial disappears before it is rendered', () async {
      _write(
        root,
        'templates/summary.liquid',
        "{% render 'templates/folder.liquid', node: root %}",
      );
      _write(root, 'templates/folder.liquid', '{{ node.path }}');
      var reads = 0;
      final sink = StringBuffer();

      expect(
        () => _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
          ),
          destination: ConsoleReportDestination(sink),
          trace: _lineTrace,
          open: (path) {
            if (path.endsWith('folder.liquid')) {
              reads += 1;
              if (reads > 1) {
                final file = _MockFile();
                when(file.existsSync).thenReturn(false);
                return file;
              }
            }
            return File(path);
          },
        ),
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );
    });
  });

  group('$StrictTemplateMap', () {
    test('returns present values and rejects unknown keys', () {
      final map = StrictTemplateMap({'hits': 0, 'source': null});

      expect(map['hits'], 0);
      expect(map['source'], isNull);
      expect(map.containsKey('hits'), isTrue);
      map['hits'] = 1;
      expect(map['hits'], 1);
      expect(
        () => map['missing'],
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );
      expect(
        () => map['missing'] = 1,
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );
      expect(
        () => map.containsKey('missing'),
        throwsA(isA<CoverageTemplateRenderFailure>()),
      );
    });
  });
}

void _write(Directory root, String relativePath, String contents) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

Future<void> _render({
  required Directory root,
  required ReportDefinition definition,
  required ReportDestination destination,
  required String trace,
  Map<String, String> variables = const {},
  CoverageSourceReader? sources,
  File Function(String path) open = File.new,
}) {
  return TemplateCoverageReporter(
    definition: definition,
    baseDirectory: root.path,
    open: open,
  ).render(
    CoverageReportRequest(
      document: CoverageDocument.parse(trace),
      sources: sources ?? const FileCoverageSourceReader(),
      destination: destination,
      variables: variables,
    ),
  );
}

final class _MapSourceReader implements CoverageSourceReader {
  _MapSourceReader(this.files);

  final Map<String, List<String>?> files;

  @override
  List<String>? readLines(String path) => files[path];
}

final class _MockFile extends Mock implements File {}

const _lineTrace = '''
SF:lib/a.dart
DA:1,1
end_of_record
''';
