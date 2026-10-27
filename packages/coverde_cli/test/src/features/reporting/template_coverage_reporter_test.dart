import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:coverde/src/features/reporting/templates/strict_template_map.dart';
import 'package:io/ansi.dart';
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

    test('exposes function and branch counts, including per line', () async {
      _write(root, 'templates/root.liquid', '''
root {{ root.functionsHit }}/{{ root.functionsFound }} {{ root.branchesHit }}/{{ root.branchesFound }}
doc {{ document.functionsHit }}/{{ document.functionsFound }} {{ document.branchesHit }}/{{ document.branchesFound }}
{%- for file in root.files %}
{%- if file.functions == null %}
{{ file.path }} functions n/a
{%- else %}
{{ file.path }} functions {{ file.functionsHit }}/{{ file.functionsFound }}
{%- for function in file.functions %}
fn {{ function.name }} {{ function.line }} {{ function.hits }}
{%- endfor %}
{%- endif %}
{%- if file.branches == null %}
{{ file.path }} branches n/a
{%- else %}
{{ file.path }} branches {{ file.branchesHit }}/{{ file.branchesFound }}
{%- for branch in file.branches %}
br {{ branch.line }} {{ branch.block }} {{ branch.branch }} {{ branch.taken }}-
{%- endfor %}
{%- for line in file.lines %}
{%- for branch in line.branches %}
lb {{ line.number }} {{ line.hits }} {{ branch.branch }} {{ branch.taken }}-
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- endfor %}
''');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
          ),
        ),
        destination: DirectoryReportDestination(destination),
        trace: '''
SF:lib/a.dart
DA:1,1
FN:1,main
FNDA:3,main
FN:4,other
BRDA:1,0,0,2
BRDA:1,0,1,-
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''',
      );

      final page = File('${destination.path}/index.html').readAsStringSync();
      expect(page, contains('root 1/2 1/2'));
      expect(page, contains('doc 1/2 1/2'));
      expect(page, contains('lib/a.dart functions 1/2'));
      expect(page, contains('fn main 1 3'));
      expect(page, contains('fn other 4 0'));
      expect(page, contains('lib/a.dart branches 1/2'));
      expect(page, contains('br 1 0 0 2-'));
      expect(page, contains('br 1 0 1 -'));
      expect(page, contains('lb 1 1 0 2-'));
      expect(page, contains('lb 1 1 1 -'));
      expect(page, contains('lib/b.dart functions n/a'));
      expect(page, contains('lib/b.dart branches n/a'));
    });

    test('writes slot pages with merged variables', () async {
      _write(root, 'templates/root.liquid', 'sort={{ variables.sort }}\n');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
            variables: {'sort': 'name'},
            pages: [
              ReportPage(
                path: 'index-sort-l.html',
                variables: {'sort': 'line'},
              ),
            ],
          ),
        ),
        destination: DirectoryReportDestination(destination),
        trace: _lineTrace,
      );

      expect(
        File('${destination.path}/index.html').readAsStringSync(),
        'sort=name\n',
      );
      expect(
        File('${destination.path}/index-sort-l.html').readAsStringSync(),
        'sort=line\n',
      );
    });

    test('uses the jailed page path for pathToRoot on extra pages', () async {
      _write(root, 'templates/root.liquid', '{{ pathToRoot }}style.css\n');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
            pages: [ReportPage(path: './nested/./page.html')],
          ),
        ),
        destination: DirectoryReportDestination(destination),
        trace: _lineTrace,
      );

      expect(
        File('${destination.path}/nested/page.html').readAsStringSync(),
        '../style.css\n',
      );
    });

    test('writes extra pages for a file slot', () async {
      _write(
        root,
        'templates/file.liquid',
        '{{ pathToRoot }}{{ file.name }}\n',
      );
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          file: const ReportSlot(
            template: 'templates/file.liquid',
            path: '{{ file.path }}.html',
            pages: [ReportPage(path: './{{ file.path }}.extra.html')],
          ),
        ),
        destination: DirectoryReportDestination(destination),
        trace: _lineTrace,
      );

      expect(
        File('${destination.path}/lib/a.dart.extra.html').readAsStringSync(),
        '../a.dart\n',
      );
    });

    test('includes source through nested directories', () async {
      _write(root, 'templates/root.liquid', '''
{%- for child in root.directories -%}
{%- for nested in child.directories -%}
{%- for file in nested.files -%}
{{ file.lines[0].source }}
{%- endfor -%}
{%- endfor -%}
{%- endfor -%}
''');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          collapse: false,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
            includeSource: true,
          ),
        ),
        destination: DirectoryReportDestination(destination),
        sources: _MapSourceReader(const {
          'lib/src/a.dart': ['body'],
        }),
        trace: '''
SF:lib/src/a.dart
DA:1,1
end_of_record
''',
      );

      expect(
        File('${destination.path}/index.html').readAsStringSync(),
        contains('body'),
      );
    });

    test('prints the trace modification time when one was provided', () async {
      _write(
        root,
        'templates/summary.liquid',
        '{{ document.traceModifiedAt }}-',
      );
      final sink = StringBuffer();
      const definition = ConsoleReportDefinition(
        template: 'templates/summary.liquid',
      );

      await _render(
        root: root,
        definition: definition,
        destination: ConsoleReportDestination(sink),
        trace: _lineTrace,
      );
      expect(sink.toString(), '-');

      sink.clear();
      await _render(
        root: root,
        definition: definition,
        destination: ConsoleReportDestination(sink),
        trace: _lineTrace,
        traceModifiedAt: DateTime.utc(2026, 10, 26, 15, 4),
      );
      expect(sink.toString(), '2026-10-26T15:04:00.000Z-');
    });

    test('prints test names from TN records', () async {
      _write(root, 'templates/summary.liquid', '''
{%- for name in document.testNames %}{{ name }}
{% endfor %}
{%- for file in document.files %}{{ file.path }} {{ file.testName }}
{% endfor %}
''');
      final sink = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(sink),
        trace: '''
SF:lib/a.dart
TN:suite
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''',
      );

      expect(sink.toString(), 'suite\nlib/a.dart suite\nlib/b.dart \n\n');
    });

    test(
      'includes source on a console report without changing other pages',
      () async {
        _write(root, 'templates/summary.liquid', '''
{%- for file in document.files %}
{{ file.path }} {{ file.sourceAvailable }} {{ file.lines[1].source }}
{%- endfor %}
{%- for file in root.files %}
root {{ file.lines[0].source }}
{%- endfor %}
''');
        _write(
          root,
          'templates/file.liquid',
          '{{ file.sourceAvailable }} {{ file.lines[0].source }}\n',
        );
        final sink = StringBuffer();
        final destination = Directory('${root.path}/out');

        await _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
            includeSource: true,
          ),
          destination: ConsoleReportDestination(sink),
          sources: _MapSourceReader(const {
            'lib/a.dart': ['one', 'two'],
          }),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''',
        );
        await _render(
          root: root,
          definition: FilesReportDefinition(
            destination: destination.path,
            file: const ReportSlot(
              template: 'templates/file.liquid',
              path: '{{ file.path }}.html',
            ),
          ),
          destination: DirectoryReportDestination(destination),
          sources: _MapSourceReader(const {
            'lib/a.dart': ['one', 'two'],
          }),
          trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        );

        expect(sink.toString(), contains('lib/a.dart true two'));
        expect(sink.toString(), contains('lib/b.dart false '));
        expect(sink.toString(), contains('root one'));
        expect(
          File('${destination.path}/lib/a.dart.html').readAsStringSync().trim(),
          isEmpty,
        );
      },
    );

    test('includes source on a directory page only', () async {
      _write(root, 'templates/root.liquid', '''
{%- for file in root.directories.first.files %}
root {{ file.lines[0].source }}-
{%- endfor %}
''');
      _write(root, 'templates/directory.liquid', '''
{%- for file in directory.files %}
dir {{ file.sourceAvailable }} {{ file.lines[0].source }}
{%- endfor %}
''');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
          ),
          directory: const ReportSlot(
            template: 'templates/directory.liquid',
            path: '{{ directory.path }}/index.html',
            includeSource: true,
          ),
        ),
        destination: DirectoryReportDestination(destination),
        sources: _MapSourceReader(const {
          'lib/src/b.dart': ['body'],
        }),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/src/b.dart
DA:1,0
end_of_record
''',
      );

      expect(
        File('${destination.path}/index.html').readAsStringSync(),
        contains('root -'),
      );
      expect(
        File('${destination.path}/lib/src/index.html').readAsStringSync(),
        contains('dir true body'),
      );
    });

    test('walks the directory tree from a console report', () async {
      _write(root, 'templates/summary.liquid', '''
{{ root.path }}
{%- for directory in root.directories %}
dir {{ directory.path }} out {{ directory.outputPath }}-
{%- for file in directory.files %}
file {{ file.path }} out {{ file.outputPath }}-
{%- endfor %}
{%- endfor %}
{%- for file in root.files %}
root-file {{ file.path }}
{%- endfor %}
''');
      final sink = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(sink),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/src/b.dart
DA:1,0
end_of_record
''',
      );

      final text = sink.toString();
      expect(text, contains('lib'));
      expect(text, contains('dir lib/src out -'));
      expect(text, contains('file lib/src/b.dart out -'));
      expect(text, contains('root-file lib/a.dart'));
    });

    test('prints unrecognized trace lines', () async {
      _write(root, 'templates/summary.liquid', '''
{%- for file in document.files %}
{%- for line in file.unrecognized %}{{ line }}{% endfor %}
{%- endfor %}
''');
      final sink = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(sink),
        trace: '''
SF:lib/a.dart
DA:1,1
XX:extra
end_of_record
''',
      );

      expect(sink.toString(), contains('XX:extra'));
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

        final comment = File(
          '${destination.path}/comment.md',
        ).readAsStringSync();
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
<h1>{{ file.path }} {{ file.sourceAvailable }}</h1>
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
      final directoryPage = File(
        '${destination.path}/lib/src/index.html',
      ).readAsStringSync();
      expect(directoryPage, contains('href="../../report.css"'));
      expect(directoryPage, contains('href="../../lib/src/app.dart.html"'));
      final filePage = File(
        '${destination.path}/lib/src/app.dart.html',
      ).readAsStringSync();
      expect(filePage, contains('<h1>lib/src/app.dart true</h1>'));
      expect(filePage, contains('1||class App {'));
      expect(filePage, contains('2|3|  return;'));
      expect(filePage, contains('3||}'));
      expect(
        File('${destination.path}/lib/a.dart.html').readAsStringSync(),
        contains('<h1>lib/a.dart false</h1>'),
      );
      expect(
        File('${destination.path}/report.css').readAsStringSync(),
        'body{}\n',
      );
    });

    test('reads a child output path from the parent path template', () async {
      _write(
        root,
        'templates/root.liquid',
        '{{ root.directories.first.outputPath }}',
      );
      _write(root, 'templates/directory.liquid', 'dir\n');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: FilesReportDefinition(
          destination: destination.path,
          root: const ReportSlot(
            template: 'templates/root.liquid',
            path: 'index.html',
          ),
          directory: const ReportSlot(
            template: 'templates/directory.liquid',
            path: '{{ directory.path }}/index.html',
          ),
        ),
        destination: DirectoryReportDestination(destination),
        trace: '''
SF:lib/a/x.dart
DA:1,1
end_of_record
SF:lib/b/y.dart
DA:1,0
end_of_record
''',
      );

      expect(
        File('${destination.path}/index.html').readAsStringSync(),
        'lib/a/index.html',
      );
    });

    test('maps rooted paths onto the report namespaces', () async {
      _write(root, 'templates/summary.liquid', '''
{% for file in document.files %}{{ file.path | report_path }}
{% endfor %}
''');
      final buffer = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:absolute/local.dart
DA:1,1
end_of_record
SF:/tmp/a.dart
DA:1,1
end_of_record
SF:C:/lib/b.dart
DA:1,1
end_of_record
SF:C:relative.dart
DA:1,1
end_of_record
SF://server/share/c.dart
DA:1,1
end_of_record
''',
      );

      expect(
        buffer.toString(),
        'absolute/local.dart\n'
        'absolute-2/tmp/a.dart\n'
        'drive-c/lib/b.dart\n'
        'drive-c-relative/relative.dart\n'
        'unc-server-share/c.dart\n'
        '\n',
      );
    });

    test(
      'keeps a single-child directory chain when collapse is false',
      () async {
        const nested =
            'root.directories.first.directories.first.directories.first.path';
        _write(
          root,
          'templates/summary.liquid',
          '[{{ root.path }}][{{ $nested }}]',
        );
        final buffer = StringBuffer();

        await _render(
          root: root,
          definition: const ConsoleReportDefinition(
            template: 'templates/summary.liquid',
            collapse: false,
          ),
          destination: ConsoleReportDestination(buffer),
          trace: '''
SF:lib/src/deep/a.dart
DA:1,1
end_of_record
''',
        );

        expect(buffer.toString(), '[][lib/src/deep]');
      },
    );

    test('coerces numeric strings and keeps a null round null', () async {
      _write(root, 'templates/summary.liquid', '''
{{ variables["width"] | minus: 1 }}
{{ variables["width"] | times: "2" }}
{{ document.branchRate | round: 2 }}-
{{ "1.26" | round: variables["places"] }}
''');
      final buffer = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        variables: const {'width': '8', 'places': '2'},
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
      );

      expect(buffer.toString(), '7\n16\n-\n1.26\n');
    });

    test('rounds without a precision and rejects a missing operand', () async {
      _write(root, 'templates/summary.liquid', '{{ "1.6" | round }}');
      final buffer = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
      );
      expect(buffer.toString(), '2');

      for (final filter in ['minus', 'times']) {
        _write(root, 'templates/summary.liquid', '{{ 1 | $filter }}');
        await expectLater(
          _render(
            root: root,
            definition: const ConsoleReportDefinition(
              template: 'templates/summary.liquid',
            ),
            destination: ConsoleReportDestination(StringBuffer()),
            trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
          ),
          throwsA(isA<CoverageTemplateRenderFailure>()),
        );
      }
    });

    test('aligns, truncates, and fixes numbers', () async {
      _write(root, 'templates/summary.liquid', '''
[{{ "hi" | pad: "4" }}]
[{{ "hi" | pad: 4, "right" }}]
[{{ "toolong" | pad: 3 }}]
[{{ "abcdefghijk" | truncate: 10 }}]
[{{ "ab" | truncate: 10 }}]
[{{ "abcdef" | truncate: 2 }}]
[{{ "ab" | truncate: -1 }}]
[{{ 100 | fixed: 2 }}]
[{{ document.branchRate | fixed: 2 }}]
[{{ 1 | fixed }}]
[{{ document.branchRate | pad: 2 }}]
[{{ document.branchRate | truncate: 2 }}]
[{{ "x" | fixed: 0 }}]
''');
      final buffer = StringBuffer();

      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
      );

      expect(
        buffer.toString(),
        '[hi  ]\n'
        '[  hi]\n'
        '[toolong]\n'
        '[...efghijk]\n'
        '[ab]\n'
        '[ef]\n'
        '[ab]\n'
        '[100.00]\n'
        '[]\n'
        '[1]\n'
        '[  ]\n'
        '[]\n'
        '[0]\n',
      );
    });

    test('exposes the terminal width', () async {
      _write(root, 'templates/summary.liquid', '{{ columns }}');
      final buffer = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        columns: 120,
      );

      expect(buffer.toString(), '120');
    });

    test('reads a coverage threshold by name', () async {
      _write(root, 'templates/summary.liquid', '{{ thresholds["pkg-min"] }}');
      final buffer = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
        thresholds: const {'pkg-min': 90},
      );

      expect(buffer.toString(), '90');
    });

    test('sorts by a rate and leaves null rates last', () async {
      _write(root, 'templates/summary.liquid', '''
{% assign files = document.files | sort_by_rate %}
{% for file in files %}{{ file.path }}
{% endfor %}
{% assign down = document.files | sort_by_rate: "lineRate", "desc" %}
{% for file in down %}{{ file.path }}
{% endfor %}
{{ "x" | sort_by_rate }}
''');
      final buffer = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(buffer),
        trace: '''
SF:lib/mid.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/none.dart
FN:1,main
FNDA:1,main
end_of_record
SF:lib/also.dart
FN:1,other
FNDA:0,other
end_of_record
SF:lib/low.dart
DA:1,0
end_of_record
''',
      );

      expect(
        buffer.toString(),
        '\n'
        'lib/low.dart\n'
        'lib/mid.dart\n'
        'lib/none.dart\n'
        'lib/also.dart\n'
        '\n'
        '\n'
        'lib/mid.dart\n'
        'lib/low.dart\n'
        'lib/none.dart\n'
        'lib/also.dart\n'
        '\n'
        'x\n',
      );
    });

    test('renders an asset as a template and copies the rest', () async {
      _write(root, 'templates/page.liquid', 'page');
      _write(
        root,
        'assets/banner.liquid',
        '{{ document.linesHit }}-{{ thresholds["pkg-min"] }}',
      );
      _write(root, 'assets/plain.css', 'body { } {{ document.linesHit }}');
      final destination = Directory('${root.path}/out');

      await _render(
        root: root,
        definition: const FilesReportDefinition(
          destination: 'ignored',
          root: ReportSlot(
            template: 'templates/page.liquid',
            path: 'index.html',
          ),
          assets: [
            ReportAsset(
              from: 'assets/banner.liquid',
              to: 'banner.txt',
              render: true,
            ),
            ReportAsset(from: 'assets/plain.css', to: 'plain.css'),
          ],
        ),
        destination: DirectoryReportDestination(destination),
        thresholds: const {'pkg-min': 80},
        trace: '''
SF:lib/a.dart
DA:1,1
end_of_record
''',
      );

      expect(File('${destination.path}/banner.txt').readAsStringSync(), '1-80');
      expect(
        File('${destination.path}/plain.css').readAsStringSync(),
        'body { } {{ document.linesHit }}',
      );
    });

    test('colors text only when color is enabled', () async {
      _write(root, 'templates/summary.liquid', '''
{{ "hi" | colorize: "light_red" }}
{{ "hi" | colorize: "light_green" }}
{{ "hi" | colorize: "red_bold" }}
{{ "hi" | colorize: "green_bold" }}
{{ "hi" | colorize: "blue_bold" }}
{{ "hi" | colorize: "other" }}
{{ document.branchRate | colorize: "light_red" }}
{{ "z" | colorize }}
{{ color }}
''');
      const trace = '''
SF:lib/a.dart
DA:1,1
end_of_record
''';
      final plain = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(plain),
        trace: trace,
      );
      expect(plain.toString(), 'hi\nhi\nhi\nhi\nhi\nhi\n\nz\nfalse\n');

      final colored = StringBuffer();
      await _render(
        root: root,
        definition: const ConsoleReportDefinition(
          template: 'templates/summary.liquid',
        ),
        destination: ConsoleReportDestination(colored),
        trace: trace,
        color: true,
      );
      expect(
        colored.toString(),
        '${wrapWith('hi', [lightRed])}\n'
        '${wrapWith('hi', [lightGreen])}\n'
        '${wrapWith('hi', [red, styleBold])}\n'
        '${wrapWith('hi', [green, styleBold])}\n'
        '${wrapWith('hi', [blue, styleBold])}\n'
        'hi\n'
        '\n'
        'z\n'
        'true\n',
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
        _write(root, 'templates/file.liquid', '{{ file.sourceAvailable }}\n');
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
          'false',
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

    test('checks a later render of the same partial on its own', () async {
      _write(root, 'templates/summary.liquid', '''
{% render 'templates/row.liquid', label: document.linesHit %}
{% render 'templates/row.liquid', other: document.linesFound %}
''');
      _write(root, 'templates/row.liquid', '{{ label }}');
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
            contains('label'),
          ),
        ),
      );
    });

    test('keeps an assignment made inside a for loop', () async {
      _write(root, 'templates/summary.liquid', '''
{% for file in document.files %}
{% assign label = file.path %}
{% endfor %}
{{ label }}
''');
      final sink = StringBuffer();

      await _render(
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
      );

      expect(sink.toString(), contains('lib/a.dart'));
    });

    test('keeps a capture for a class name that contains a space', () async {
      _write(root, 'templates/summary.liquid', '''
{% capture class %}covValue headerCovTableEntryLo{% endcapture %}
<td class="{{ class }}">
''');
      final sink = StringBuffer();

      await _render(
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
      );

      expect(
        sink.toString(),
        contains('<td class="covValue headerCovTableEntryLo">'),
      );
    });

    test('rejects the loop variable and forloop after the loop', () async {
      final sink = StringBuffer();
      const trace = '''
SF:lib/a.dart
DA:1,1
end_of_record
''';

      for (final name in ['item', 'forloop']) {
        _write(root, 'templates/summary.liquid', '''
{% for item in document.files %}
{{ item.path }}
{% endfor %}
{{ $name }}
''');
        await expectLater(
          _render(
            root: root,
            definition: const ConsoleReportDefinition(
              template: 'templates/summary.liquid',
            ),
            destination: ConsoleReportDestination(sink),
            trace: trace,
          ),
          throwsA(
            isA<CoverageTemplateRenderFailure>().having(
              (failure) => failure.readableMessage,
              'readableMessage',
              contains(name),
            ),
          ),
        );
      }
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
  DateTime? traceModifiedAt,
  Map<String, String> variables = const {},
  CoverageSourceReader? sources,
  File Function(String path) open = File.new,
  int columns = 80,
  bool color = false,
  Map<String, num> thresholds = const {},
}) {
  return TemplateCoverageReporter(
    definition: definition,
    baseDirectory: root.path,
    open: open,
  ).render(
    CoverageReportRequest(
      document: CoverageDocument.parse(trace, traceModifiedAt: traceModifiedAt),
      sources: sources ?? const FileCoverageSourceReader(),
      destination: destination,
      variables: variables,
      columns: columns,
      color: color,
      thresholds: thresholds,
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
