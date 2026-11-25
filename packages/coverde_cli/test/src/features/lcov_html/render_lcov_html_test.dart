// cspell:ignore genhtml gcov
//
// The built-in report is compared to the LCOV genhtml fixtures. Whitespace
// between tags is ignored. Text and attributes are not.
//
// Function links follow genhtml 2.0-1: the recorded line minus 2, and never
// below line 1.

import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/features/lcov_html/render_lcov_html.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory output;

  setUp(() {
    output = Directory.systemTemp.createTempSync('coverde-lcov-html-');
  });

  tearDown(() {
    if (output.existsSync()) output.deleteSync(recursive: true);
  });

  test('built-in lcov-html matches the genhtml reference', () async {
    final packageRoot = Directory.current.path;
    final fixture = p.join(
      packageRoot,
      'test',
      'src',
      'features',
      'lcov_html',
      'fixtures',
      'genhtml',
    );
    final sources = p.join(
      packageRoot,
      'e2e',
      'suite',
      'e2e',
      'commands',
      'render',
      'fixtures',
      'project',
    );
    final trace = File(p.join(fixture, 'trace.lcov.info')).readAsStringSync();
    await renderLcovHtmlReport(
      document: CoverageDocument.parse(
        trace,
        traceModifiedAt: DateTime(2026, 11, 25),
      ),
      sources: FileCoverageSourceReader(
        open: (path) => File(p.join(sources, path)),
      ),
      output: output,
    );

    final expected = _files(
      fixture,
    ).where((path) => p.basename(path) != 'trace.lcov.info');
    final actual = _files(output.path);
    expect(actual, expected.toSet());

    for (final relative in expected) {
      final expectedFile = File(p.join(fixture, relative));
      final actualFile = File(p.join(output.path, relative));
      if (relative.endsWith('.html')) {
        expect(
          _difference(
            actualFile.readAsStringSync(),
            expectedFile.readAsStringSync(),
          ),
          isNull,
          reason: relative,
        );
      } else {
        expect(
          actualFile.readAsBytesSync(),
          expectedFile.readAsBytesSync(),
          reason: relative,
        );
      }
    }
  });
}

Set<String> _files(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.relative(file.path, from: root).replaceAll(r'\', '/'))
      .toSet();
}

String? _difference(String actual, String expected) {
  return _compareNodes(
    parse(actual).documentElement!,
    parse(expected).documentElement!,
    'html',
  );
}

String? _compareNodes(Node actual, Node expected, String path) {
  if (actual is Text || expected is Text) {
    final actualText = actual is Text ? actual.text : null;
    final expectedText = expected is Text ? expected.text : null;
    if (actualText != expectedText) {
      return '$path\nactual:   ${actualText ?? actual.runtimeType}\n'
          'expected: ${expectedText ?? expected.runtimeType}';
    }
    return null;
  }
  if (actual is! Element || expected is! Element) {
    return '$path node types differ';
  }
  if (actual.localName != expected.localName) {
    return '$path <${actual.localName}> != <${expected.localName}>';
  }
  final attributeDifference = _compareAttributes(actual, expected, path);
  if (attributeDifference != null) return attributeDifference;
  final actualChildren = _significant(actual);
  final expectedChildren = _significant(expected);
  if (actualChildren.length != expectedChildren.length) {
    return '$path <${actual.localName}> has ${actualChildren.length} '
        'children, expected ${expectedChildren.length}';
  }
  for (var index = 0; index < actualChildren.length; index++) {
    final difference = _compareNodes(
      actualChildren[index],
      expectedChildren[index],
      '$path/${_step(actualChildren[index], index)}',
    );
    if (difference != null) return difference;
  }
  return null;
}

String? _compareAttributes(Element actual, Element expected, String path) {
  final actualKeys = actual.attributes.keys.map((key) => '$key').toSet();
  final expectedKeys = expected.attributes.keys.map((key) => '$key').toSet();
  if (actualKeys.length != expectedKeys.length ||
      !actualKeys.containsAll(expectedKeys)) {
    return '$path <${actual.localName}> attributes '
        '$actualKeys != $expectedKeys';
  }
  for (final key in actualKeys) {
    final actualValue = actual.attributes[key];
    final expectedValue = expected.attributes[key];
    if (actualValue != expectedValue) {
      return '$path <${actual.localName}> $key\n'
          'actual:   $actualValue\nexpected: $expectedValue';
    }
  }
  return null;
}

List<Node> _significant(Element element) {
  return [
    for (final child in element.nodes)
      if (child is Element || (child is Text && child.text.trim().isNotEmpty))
        child,
  ];
}

String _step(Node node, int index) {
  if (node is Element) return '${node.localName}[$index]';
  return 'text[$index]';
}
