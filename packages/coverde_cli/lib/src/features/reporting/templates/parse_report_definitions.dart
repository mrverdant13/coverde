import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:coverde/src/features/reporting/templates/report_definition.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

/// Reads the `reports` map from a `coverde.yaml` document.
///
/// [baseDirectory] is the directory that contains the yaml file. Relative
/// destinations are resolved against it. A missing `reports` member yields an
/// empty map.
///
/// Throws [CoverageReportDefinitionFailure] when a report is present but
/// invalid.
Map<String, ReportDefinition> parseReportDefinitions(
  String yamlString, {
  required String baseDirectory,
}) {
  final dynamic rawConfig;
  try {
    rawConfig = yaml.loadYaml(yamlString);
  } on yaml.YamlException catch (exception) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Invalid report configuration.\n$exception',
    );
  }
  if (rawConfig == null) return const {};
  if (rawConfig is! yaml.YamlMap) {
    throw const CoverageReportDefinitionFailure(
      readableMessage: 'Report configuration must be a YAML map.',
    );
  }
  if (!rawConfig.containsKey('reports')) return const {};
  final rawReports = rawConfig['reports'];
  if (rawReports is! yaml.YamlMap) {
    throw const CoverageReportDefinitionFailure(
      readableMessage: '`reports` must be a map of report names.',
    );
  }
  final reports = <String, ReportDefinition>{};
  for (final entry in rawReports.entries) {
    final name = entry.key;
    if (name is! String || name.isEmpty) {
      throw const CoverageReportDefinitionFailure(
        readableMessage: 'Report names must be non-empty strings.',
      );
    }
    reports[name] = _parseReport(
      name: name,
      value: entry.value,
      baseDirectory: baseDirectory,
    );
  }
  return reports;
}

/// Selects [reportName] from [reports].
///
/// When [reportName] is null and [reports] has one entry, that report is used.
///
/// Throws [UnknownCoverageReportFailure] when [reportName] is not defined.
/// Throws [CoverageReportDefinitionFailure] when the choice is ambiguous or
/// there are no reports.
ReportDefinition resolveReportDefinition({
  required Map<String, ReportDefinition> reports,
  required String? reportName,
  required String configPath,
}) {
  if (reportName == null) {
    if (reports.length == 1) return reports.values.single;
    final available = reports.keys.toList()..sort();
    final message = reports.isEmpty
        ? 'No reports are defined in `$configPath`.'
        : '`$configPath` defines more than one report.\n'
              'Pass --report with one of: ${available.join(', ')}.';
    throw CoverageReportDefinitionFailure(readableMessage: message);
  }
  final report = reports[reportName];
  if (report == null) {
    throw UnknownCoverageReportFailure(
      reportName: reportName,
      configPath: configPath,
      availableReports: reports.keys.toList()..sort(),
    );
  }
  return report;
}

ReportDefinition _parseReport({
  required String name,
  required dynamic value,
  required String baseDirectory,
}) {
  if (value is! yaml.YamlMap) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` must be a map.',
    );
  }
  final type = value['type'];
  if (type is! String) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` is missing a `type`.',
    );
  }
  return switch (type) {
    'console' => _parseConsoleReport(
      name: name,
      value: value,
      baseDirectory: baseDirectory,
    ),
    'files' => _parseFilesReport(
      name: name,
      value: value,
      baseDirectory: baseDirectory,
    ),
    _ => throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` has unknown type `$type`.',
    ),
  };
}

ConsoleReportDefinition _parseConsoleReport({
  required String name,
  required yaml.YamlMap value,
  required String baseDirectory,
}) {
  for (final key in ['root', 'directory', 'file', 'assets']) {
    if (value.containsKey(key)) {
      throw CoverageReportDefinitionFailure(
        readableMessage: 'Console report `$name` cannot set `$key`.',
      );
    }
  }
  const allowed = {'type', 'template', 'includeSource', 'destination'};
  _rejectUnknownKeys(name: name, value: value, allowed: allowed);
  final includeSource = value['includeSource'];
  if (includeSource != null && includeSource is! bool) {
    throw CoverageReportDefinitionFailure(
      readableMessage:
          'Console report `$name` `includeSource` must be a boolean.',
    );
  }
  final destination = value['destination'];
  if (destination != null &&
      (destination is! String || destination.trim().isEmpty)) {
    throw CoverageReportDefinitionFailure(
      readableMessage:
          'Console report `$name` `destination` must be a non-empty string.',
    );
  }
  return ConsoleReportDefinition(
    template: _requiredString(name, value, 'template'),
    includeSource: includeSource == true,
    destination: destination is String
        ? path.normalize(path.join(baseDirectory, destination))
        : null,
  );
}

FilesReportDefinition _parseFilesReport({
  required String name,
  required yaml.YamlMap value,
  required String baseDirectory,
}) {
  _rejectUnknownKeys(
    name: name,
    value: value,
    allowed: {'type', 'destination', 'root', 'directory', 'file', 'assets'},
  );
  final destination = value['destination'];
  if (destination is! String || destination.trim().isEmpty) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Files report `$name` requires `destination`.',
    );
  }
  final root = _parseSlot(name: name, slot: 'root', value: value['root']);
  final directory = _parseSlot(
    name: name,
    slot: 'directory',
    value: value['directory'],
  );
  final file = _parseSlot(name: name, slot: 'file', value: value['file']);
  if (root == null && directory == null && file == null) {
    throw CoverageReportDefinitionFailure(
      readableMessage:
          'Files report `$name` requires `root`, `directory`, or `file`.',
    );
  }
  return FilesReportDefinition(
    destination: path.normalize(path.join(baseDirectory, destination)),
    root: root,
    directory: directory,
    file: file,
    assets: _parseAssets(name: name, value: value['assets']),
  );
}

ReportSlot? _parseSlot({
  required String name,
  required String slot,
  required dynamic value,
}) {
  if (value == null) return null;
  if (value is! yaml.YamlMap) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` slot `$slot` must be a map.',
    );
  }
  final allowed = {'template', 'path', 'includeSource'};
  _rejectUnknownKeys(name: '$name.$slot', value: value, allowed: allowed);
  final includeSource = value['includeSource'];
  if (includeSource != null && includeSource is! bool) {
    throw CoverageReportDefinitionFailure(
      readableMessage:
          'Report `$name` slot `$slot` `includeSource` must be a boolean.',
    );
  }
  return ReportSlot(
    template: _requiredString('$name.$slot', value, 'template'),
    path: _requiredString('$name.$slot', value, 'path'),
    includeSource: includeSource == true,
  );
}

List<ReportAsset> _parseAssets({required String name, required dynamic value}) {
  if (value == null) return const [];
  if (value is! yaml.YamlList) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` `assets` must be a list.',
    );
  }
  return [
    for (final (index, asset) in value.indexed)
      _parseAsset(name: name, index: index, value: asset),
  ];
}

ReportAsset _parseAsset({
  required String name,
  required int index,
  required dynamic value,
}) {
  if (value is! yaml.YamlMap) {
    throw CoverageReportDefinitionFailure(
      readableMessage: 'Report `$name` asset ${index + 1} must be a map.',
    );
  }
  _rejectUnknownKeys(
    name: '$name.assets[${index + 1}]',
    value: value,
    allowed: {'from', 'to'},
  );
  return ReportAsset(
    from: _requiredString('$name.assets[${index + 1}]', value, 'from'),
    to: _requiredString('$name.assets[${index + 1}]', value, 'to'),
  );
}

String _requiredString(String owner, yaml.YamlMap value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw CoverageReportDefinitionFailure(
      readableMessage: '`$owner` requires `$key` to be a non-empty string.',
    );
  }
  return raw;
}

void _rejectUnknownKeys({
  required String name,
  required yaml.YamlMap value,
  required Set<String> allowed,
}) {
  for (final key in value.keys) {
    if (key is! String || !allowed.contains(key)) {
      throw CoverageReportDefinitionFailure(
        readableMessage: 'Report `$name` has unknown key `$key`.',
      );
    }
  }
}
