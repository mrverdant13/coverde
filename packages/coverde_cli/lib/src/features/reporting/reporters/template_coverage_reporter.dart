import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_report_request.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_reporter.dart';
import 'package:coverde/src/features/reporting/reporters/report_destination.dart';
import 'package:coverde/src/features/reporting/templates/coercing_plus.dart';
import 'package:coverde/src/features/reporting/templates/compact_ranges.dart';
import 'package:coverde/src/features/reporting/templates/jailed_path.dart';
import 'package:coverde/src/features/reporting/templates/liquid_variables.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:coverde/src/features/reporting/templates/strict_template_map.dart';
import 'package:coverde/src/features/reporting/templates/template_context.dart';
import 'package:liquify/liquify.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template coverde.template_coverage_reporter}
/// Renders a [ReportDefinition] with Liquid templates.
/// {@endtemplate}
final class TemplateCoverageReporter implements CoverageReporter {
  /// {@macro coverde.template_coverage_reporter}
  TemplateCoverageReporter({
    required this.definition,
    required this.baseDirectory,
    @visibleForTesting File Function(String path) open = File.new,
  }) : _open = open;

  /// The report to render.
  final ReportDefinition definition;

  /// Directory that template paths are resolved against.
  final String baseDirectory;

  final File Function(String path) _open;

  static const _knownNames = {
    'document',
    'variables',
    'pathToRoot',
    'root',
    'directory',
    'file',
  };

  static var _filtersRegistered = false;

  static void _registerFilters() {
    if (_filtersRegistered) return;
    FilterRegistry.register('compact_ranges', compactRanges);
    FilterRegistry.register('plus', coercingPlus);
    _filtersRegistered = true;
  }

  @override
  Future<void> render(CoverageReportRequest request) async {
    _registerFilters();
    switch (definition) {
      case ConsoleReportDefinition(:final template):
        final destination = request.destination;
        if (destination is! ConsoleReportDestination) {
          throw const CoverageReportDefinitionFailure(
            readableMessage: 'A console report writes to a console sink.',
          );
        }
        destination.sink.write(
          await _renderTemplate(
            template: template,
            data: _data(
              context: TemplateContext(
                document: request.document,
                sources: request.sources,
              ),
              variables: request.variables,
              pathToRoot: '',
            ),
          ),
        );
      case FilesReportDefinition():
        final destination = request.destination;
        if (destination is! DirectoryReportDestination) {
          throw const CoverageReportDefinitionFailure(
            readableMessage: 'A files report writes to a directory.',
          );
        }
        await _renderFiles(
          request,
          definition as FilesReportDefinition,
          destination,
        );
    }
  }

  Future<void> _renderFiles(
    CoverageReportRequest request,
    FilesReportDefinition definition,
    DirectoryReportDestination destination,
  ) async {
    final context = TemplateContext(
      document: request.document,
      sources: request.sources,
    );
    final variables = request.variables;
    final written = <String>{};
    await _assignDirectoryPaths(
      directory: request.document.tree,
      map: context.root,
      isRoot: true,
      definition: definition,
      context: context,
      variables: variables,
      destination: destination.directory.path,
      written: written,
    );
    await _renderDirectory(
      directory: request.document.tree,
      map: context.root,
      isRoot: true,
      definition: definition,
      context: context,
      variables: variables,
      destination: destination.directory.path,
    );
    for (final asset in definition.assets) {
      final source = resolveInsideRoot(
        rootDirectory: baseDirectory,
        relativePath: asset.from,
        description: 'Asset source',
      );
      final target = resolveInsideRoot(
        rootDirectory: destination.directory.path,
        relativePath: asset.to,
        description: 'Asset path',
      );
      final relative = relativeReportPath(
        rootDirectory: destination.directory.path,
        resolvedPath: target,
      );
      if (!written.add(relative)) {
        throw CoverageReportPathFailure(
          readableMessage: 'Report path `$relative` is written more than once.',
        );
      }
      _copyFile(source, target);
    }
  }

  Future<void> _assignDirectoryPaths({
    required CoverageDirectory directory,
    required StrictTemplateMap map,
    required bool isRoot,
    required FilesReportDefinition definition,
    required TemplateContext context,
    required Map<String, String> variables,
    required String destination,
    required Set<String> written,
  }) async {
    final slot =
        isRoot ? definition.root ?? definition.directory : definition.directory;
    if (slot != null) {
      final binding = isRoot && definition.root != null ? 'root' : 'directory';
      map['outputPath'] = await _outputPath(
        slot: slot,
        data: _data(
          context: context,
          variables: variables,
          pathToRoot: '',
          root: binding == 'root' ? map : null,
          directory: binding == 'directory' ? map : null,
        ),
        destination: destination,
        written: written,
      );
    }
    final childMaps = map['directories']! as List<Object?>;
    for (var index = 0; index < directory.directories.length; index++) {
      await _assignDirectoryPaths(
        directory: directory.directories[index],
        map: childMaps[index]! as StrictTemplateMap,
        isRoot: false,
        definition: definition,
        context: context,
        variables: variables,
        destination: destination,
        written: written,
      );
    }
    final fileSlot = definition.file;
    if (fileSlot == null) return;
    for (final file in directory.files) {
      final fileMap = context.fileMap(file);
      fileMap['outputPath'] = await _outputPath(
        slot: fileSlot,
        data: _data(
          context: context,
          variables: variables,
          pathToRoot: '',
          file: fileMap,
        ),
        destination: destination,
        written: written,
      );
    }
  }

  Future<void> _renderDirectory({
    required CoverageDirectory directory,
    required StrictTemplateMap map,
    required bool isRoot,
    required FilesReportDefinition definition,
    required TemplateContext context,
    required Map<String, String> variables,
    required String destination,
  }) async {
    final slot =
        isRoot ? definition.root ?? definition.directory : definition.directory;
    if (slot != null) {
      final binding = isRoot && definition.root != null ? 'root' : 'directory';
      final relative = map['outputPath']! as String;
      await _writeRendered(
        slot: slot,
        relativePath: relative,
        destination: destination,
        data: _data(
          context: context,
          variables: variables,
          pathToRoot: pathToRootPrefix(relative),
          root: binding == 'root' ? map : null,
          directory: binding == 'directory' ? map : null,
        ),
      );
    }
    final childMaps = map['directories']! as List<Object?>;
    for (var index = 0; index < directory.directories.length; index++) {
      await _renderDirectory(
        directory: directory.directories[index],
        map: childMaps[index]! as StrictTemplateMap,
        isRoot: false,
        definition: definition,
        context: context,
        variables: variables,
        destination: destination,
      );
    }
    final fileSlot = definition.file;
    if (fileSlot == null) return;
    for (final file in directory.files) {
      await _renderFile(
        file: file,
        slot: fileSlot,
        context: context,
        variables: variables,
        destination: destination,
      );
    }
  }

  Future<void> _renderFile({
    required CoverageFile file,
    required ReportSlot slot,
    required TemplateContext context,
    required Map<String, String> variables,
    required String destination,
  }) async {
    final relative = context.fileMap(file)['outputPath']! as String;
    await _writeRendered(
      slot: slot,
      relativePath: relative,
      destination: destination,
      data: _data(
        context: context,
        variables: variables,
        pathToRoot: pathToRootPrefix(relative),
        file: context.fileRenderMap(file, includeSource: slot.includeSource),
      ),
    );
  }

  Future<String> _outputPath({
    required ReportSlot slot,
    required Map<String, Object?> data,
    required String destination,
    required Set<String> written,
  }) async {
    final rendered =
        (await _renderSource(
          source: slot.path,
          label: 'path `${slot.path}`',
          data: data,
        )).trim();
    final resolved = resolveInsideRoot(
      rootDirectory: destination,
      relativePath: rendered,
      description: 'Report path',
    );
    final relative = relativeReportPath(
      rootDirectory: destination,
      resolvedPath: resolved,
    );
    if (!written.add(relative)) {
      throw CoverageReportPathFailure(
        readableMessage: 'Report path `$relative` is written more than once.',
      );
    }
    return relative;
  }

  Future<void> _writeRendered({
    required ReportSlot slot,
    required String relativePath,
    required String destination,
    required Map<String, Object?> data,
  }) async {
    final resolved = resolveInsideRoot(
      rootDirectory: destination,
      relativePath: relativePath,
      description: 'Report path',
    );
    _writeFile(
      resolved,
      await _renderTemplate(template: slot.template, data: data),
    );
  }

  Map<String, Object?> _data({
    required TemplateContext context,
    required Map<String, String> variables,
    required String pathToRoot,
    StrictTemplateMap? root,
    StrictTemplateMap? directory,
    StrictTemplateMap? file,
  }) {
    return {
      'document': context.documentMap,
      'variables': StrictTemplateMap(Map<String, Object?>.of(variables)),
      'pathToRoot': pathToRoot,
      'root': root,
      'directory': directory,
      'file': file,
    };
  }

  Future<String> _renderTemplate({
    required String template,
    required Map<String, Object?> data,
  }) {
    return _renderSource(
      source: _readTemplate(template),
      label: template,
      data: data,
    );
  }

  Future<String> _renderSource({
    required String source,
    required String label,
    required Map<String, Object?> data,
  }) async {
    try {
      assertKnownTemplateVariables(
        source: source,
        known: _knownNames,
        readTemplate: _readTemplate,
      );
      return await Template.parse(
        source,
        data: data,
        root: _PackRoot(baseDirectory, _open),
        environmentSetup: (environment) {
          environment.registerLocalFilter('compact_ranges', compactRanges);
        },
      ).renderAsync();
    } on CoverageReportFailure {
      rethrow;
    } on Object catch (error) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Failed to render `$label`.\n$error',
      );
    }
  }

  String _readTemplate(String relativePath) {
    final resolved = resolveInsideRoot(
      rootDirectory: baseDirectory,
      relativePath: relativePath,
      description: 'Template',
    );
    final file = _open(resolved);
    if (!file.existsSync()) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Template `$relativePath` was not found.',
      );
    }
    try {
      return file.readAsStringSync();
    } on FileSystemException catch (exception) {
      throw CoverageTemplateRenderFailure(
        readableMessage:
            'Failed to read template `$relativePath`.\n${exception.message}',
      );
    }
  }

  void _writeFile(String absolutePath, String contents) {
    final file = _open(absolutePath);
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    } on FileSystemException catch (exception) {
      throw CoverageReportDestinationFailure.fromFileSystemException(
        path: absolutePath,
        exception: exception,
      );
    }
  }

  void _copyFile(String source, String target) {
    try {
      _open(target).parent.createSync(recursive: true);
      _open(source).copySync(target);
    } on FileSystemException catch (exception) {
      throw CoverageReportDestinationFailure.fromFileSystemException(
        path: target,
        exception: exception,
      );
    }
  }
}

final class _PackRoot implements Root {
  _PackRoot(this.baseDirectory, this.open);

  final String baseDirectory;
  final File Function(String path) open;

  @override
  Source resolve(String relPath) {
    final resolved = resolveInsideRoot(
      rootDirectory: baseDirectory,
      relativePath: relPath,
      description: 'Template',
    );
    final file = open(resolved);
    if (!file.existsSync()) {
      throw TemplateNotFoundException(relPath);
    }
    return Source(file.uri, file.readAsStringSync(), this);
  }

  @override
  Future<Source> resolveAsync(String relPath) async => resolve(relPath);
}
