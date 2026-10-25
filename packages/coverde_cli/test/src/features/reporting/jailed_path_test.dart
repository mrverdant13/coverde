import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:coverde/src/features/reporting/templates/jailed_path.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('coverde_jailed_path_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('resolves a file under an existing directory', () {
    final destination = Directory(p.join(root.path, 'out'))..createSync();

    final resolved = resolveInsideRoot(
      rootDirectory: destination.path,
      relativePath: 'nested/page.html',
      description: 'Report path',
    );

    expect(
      p.equals(resolved, p.join(destination.path, 'nested', 'page.html')),
      isTrue,
    );
  });

  test('rejects a resolved path that leaves the directory', () {
    final destination = Directory(p.join(root.path, 'out'))..createSync();
    Directory(p.join(destination.path, 'assets')).createSync();
    final outside = p.normalize(p.join(root.path, 'secret'));

    expect(
      () => resolveInsideRoot(
        rootDirectory: destination.path,
        relativePath: 'assets/report.css',
        description: 'Asset path',
        canonicalizeExisting: (filePath) {
          if (p.equals(filePath, p.join(destination.path, 'assets'))) {
            return outside;
          }
          return filePath;
        },
      ),
      throwsA(
        isA<CoverageReportPathFailure>().having(
          (failure) => failure.readableMessage,
          'readableMessage',
          contains('assets/report.css'),
        ),
      ),
    );
  });

  test('rejects an existing path that cannot be resolved', () {
    final destination = Directory(p.join(root.path, 'out'))..createSync();

    expect(
      () => resolveInsideRoot(
        rootDirectory: destination.path,
        relativePath: 'page.html',
        description: 'Report path',
        canonicalizeExisting: (filePath) =>
            throw FileSystemException('broken', filePath),
      ),
      throwsA(isA<CoverageReportPathFailure>()),
    );
  });

  test('rejects a symlink that points outside the destination', () async {
    final destination = Directory(p.join(root.path, 'out'))..createSync();
    final outside = Directory(p.join(root.path, 'secret'))..createSync();
    Link(p.join(destination.path, 'assets')).createSync(outside.path);
    _write(root, 'templates/page.liquid', 'x\n');
    _write(root, 'static/report.css', 'body{}\n');

    await expectLater(
      _render(
        root: root,
        destination: destination,
        assets: const [
          ReportAsset(from: 'static/report.css', to: 'assets/report.css'),
        ],
      ),
      throwsA(isA<CoverageReportPathFailure>()),
    );
    expect(File(p.join(outside.path, 'report.css')).existsSync(), isFalse);
  });

  test('follows a symlink that stays inside the destination', () async {
    final destination = Directory(p.join(root.path, 'out'))..createSync();
    final inner = Directory(p.join(destination.path, 'inner'))..createSync();
    Link(p.join(destination.path, 'linked')).createSync(inner.path);
    _write(root, 'templates/page.liquid', 'inside\n');

    await _render(
      root: root,
      destination: destination,
      path: 'linked/page.html',
    );

    expect(
      File(p.join(inner.path, 'page.html')).readAsStringSync(),
      contains('inside'),
    );
  });

  test('rejects a symlink that cannot be resolved', () async {
    final destination = Directory(p.join(root.path, 'out'))..createSync();
    Link(
      p.join(destination.path, 'broken'),
    ).createSync(p.join(root.path, 'missing'));
    _write(root, 'templates/page.liquid', 'x\n');

    await expectLater(
      _render(root: root, destination: destination, path: 'broken/page.html'),
      throwsA(isA<CoverageReportPathFailure>()),
    );
  });
}

void _write(Directory root, String relativePath, String contents) {
  final file = File(p.join(root.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

Future<void> _render({
  required Directory root,
  required Directory destination,
  String path = 'index.html',
  List<ReportAsset> assets = const [],
}) {
  return TemplateCoverageReporter(
    definition: FilesReportDefinition(
      destination: destination.path,
      root: ReportSlot(template: 'templates/page.liquid', path: path),
      assets: assets,
    ),
    baseDirectory: root.path,
  ).render(
    CoverageReportRequest(
      document: CoverageDocument.parse(_lineTrace),
      sources: const FileCoverageSourceReader(),
      destination: DirectoryReportDestination(destination),
    ),
  );
}

const _lineTrace = '''
SF:lib/a.dart
DA:1,1
end_of_record
''';
