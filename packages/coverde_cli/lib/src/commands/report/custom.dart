import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/commands/report/terminal_report.dart';
import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:coverde/src/utils/trace_merge.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// {@template report_custom_cmd}
/// A command to render one named report from `coverde.yaml`.
/// {@endtemplate}
class ReportCustomCommand extends CoverdeCommand {
  /// {@macro report_custom_cmd}
  ReportCustomCommand() {
    argParser
      ..addMultiOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Coverage trace file to render.

Repeat to merge traces. Records with the same path are merged.
The trace time is the latest modification time.''',
        valueHelp: 'TRACE_FILE',
        defaultsTo: const ['coverage/lcov.info'],
      )
      ..addOption(
        configOption,
        help: '''
Path to the coverde.yaml file.

Relative report paths resolve from that file's directory.''',
        valueHelp: 'coverde.yaml',
        defaultsTo: _configFileName,
      );
  }

  static const _configFileName = 'coverde.yaml';

  /// Option name for the trace files.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the configuration file.
  @visibleForTesting
  static const configOption = 'config';

  @override
  String get name => 'custom';

  @override
  String get description => '''
Render a named report from coverde.yaml.

The argument is the report name. Each option declared by that report is a flag.''';

  @override
  CoverdeCommandParams get params => CoverdeCommandParams(
    identifier: 'name',
    description: 'The name of a report in coverde.yaml.',
  );

  @override
  void printUsage() {
    logger.write('$usage\n');
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final name = _reportName(argResults.rest);
    final configPath = _absolute(argResults.option(configOption)!);
    final rawConfig = _readConfig(configPath);
    final definition = _definition(
      rawConfig: rawConfig,
      configPath: configPath,
      name: name,
    );
    final document = _document([
      for (final path in argResults.multiOption(inputOption)) _absolute(path),
    ]);
    final variables = {
      for (final option in definition.options.values)
        option.name: argResults.option(option.name)!,
    };

    final buffer = StringBuffer();
    final destination = switch (definition) {
      ConsoleReportDefinition() => ConsoleReportDestination(buffer),
      FilesReportDefinition(:final destination) => DirectoryReportDestination(
        Directory(destination),
      ),
    };
    await TemplateCoverageReporter(
      definition: definition,
      baseDirectory: p.dirname(configPath),
    ).render(
      CoverageReportRequest(
        document: document,
        sources: const FileCoverageSourceReader(),
        destination: destination,
        variables: variables,
        columns: reportColumns(),
        color: reportColor(printing: reportPrintsToTerminal(definition)),
        thresholds: parseCoverageThresholds(rawConfig),
      ),
    );
    if (destination is! ConsoleReportDestination) return;
    final output = (definition as ConsoleReportDefinition).destination;
    if (output == null) {
      logger.write(buffer.toString());
      return;
    }
    final file = File(output);
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(buffer.toString());
    } on FileSystemException catch (exception) {
      throw CoverageReportDestinationFailure.fromFileSystemException(
        path: output,
        exception: exception,
      );
    }
  }

  String _reportName(List<String> rest) {
    if (rest.isEmpty) {
      throw CoverdeReportMissingReportNameFailure(
        usageMessage: usageWithoutDescription,
      );
    }
    if (rest.length > 1) {
      throw CoverdeReportUnexpectedArgumentFailure(
        argument: rest[1],
        usageMessage: usageWithoutDescription,
      );
    }
    return rest.single;
  }
}

/// Registers [ReportCustomCommand] flags declared by the named report.
///
/// `--config` and the report name are read before the remaining flags, so
/// either may appear first.
void installReportCustomOptions(CommandRunner<void> runner, List<String> args) {
  final report = runner.commands['report'];
  final custom = report?.subcommands['custom'];
  if (custom is! ReportCustomCommand) return;
  final invocation = _customInvocation(args);
  if (invocation == null || invocation.name == null) return;

  final configPath = _absolute(invocation.config ?? 'coverde.yaml');
  final definition = _definition(
    rawConfig: _readConfig(configPath),
    configPath: configPath,
    name: invocation.name!,
  );
  for (final option in definition.options.values) {
    if (custom.argParser.options.containsKey(option.name)) continue;
    custom.argParser.addOption(
      option.name,
      help: option.allowed.isEmpty
          ? 'Default: ${option.defaultValue}.'
          : 'Default: ${option.defaultValue}. '
                'Allowed: ${option.allowed.join(', ')}.',
      defaultsTo: option.defaultValue,
      allowed: option.allowed.isEmpty ? null : option.allowed,
    );
  }
}

({String? name, String? config})? _customInvocation(List<String> args) {
  var index = 0;
  while (index < args.length && args[index].startsWith('-')) {
    if (args[index].contains('=')) {
      index++;
      continue;
    }
    index++;
    if (index < args.length &&
        !args[index].startsWith('-') &&
        args[index] != 'report' &&
        args[index] != 'r') {
      index++;
    }
  }
  if (index >= args.length) return null;
  if (args[index] != 'report' && args[index] != 'r') return null;
  index++;
  if (index >= args.length || args[index] != 'custom') return null;
  index++;

  String? name;
  String? config;
  while (index < args.length) {
    final arg = args[index];
    if (arg == '--help' || arg == '-h') {
      index++;
      continue;
    }
    if (arg == '--config') {
      index++;
      if (index < args.length) config = args[index++];
      continue;
    }
    if (arg.startsWith('--config=')) {
      config = arg.substring('--config='.length);
      index++;
      continue;
    }
    if (arg == '--input' || arg == '-i') {
      index += 2;
      continue;
    }
    if (arg.startsWith('--input=') || _isAttachedInput(arg)) {
      index++;
      continue;
    }
    if (arg.startsWith('--')) {
      if (!arg.contains('=')) {
        index++;
        if (index < args.length && !args[index].startsWith('-')) index++;
        continue;
      }
      index++;
      continue;
    }
    if (arg.startsWith('-')) {
      index++;
      continue;
    }
    name ??= arg;
    index++;
  }
  return (name: name, config: config);
}

bool _isAttachedInput(String arg) {
  return arg.startsWith('-i') && !arg.startsWith('--') && arg.length > 2;
}

ReportDefinition _definition({
  required String rawConfig,
  required String configPath,
  required String name,
}) {
  return resolveReportDefinition(
    reports: parseReportDefinitions(
      rawConfig,
      baseDirectory: p.dirname(configPath),
    ),
    reportName: name,
    configPath: configPath,
  );
}

String _readConfig(String configPath) {
  if (!FileSystemEntity.isFileSync(configPath)) {
    throw CoverdeReportConfigFileNotFoundFailure(configPath: configPath);
  }
  try {
    return File(configPath).readAsStringSync();
  } on FileSystemException catch (exception) {
    throw CoverdeReportConfigFileReadFailure.fromFileSystemException(
      configPath: configPath,
      exception: exception,
    );
  }
}

CoverageDocument _document(List<String> tracePaths) {
  final trace = StringBuffer();
  DateTime? traceModifiedAt;
  for (final traceFilePath in tracePaths) {
    if (!FileSystemEntity.isFileSync(traceFilePath)) {
      throw CoverdeReportTraceFileNotFoundFailure(traceFilePath: traceFilePath);
    }
    final traceFile = File(traceFilePath);
    try {
      final modified = traceFile.lastModifiedSync();
      if (traceModifiedAt == null || modified.isAfter(traceModifiedAt)) {
        traceModifiedAt = modified;
      }
      appendTraceContent(trace, traceFile.readAsStringSync());
    } on FileSystemException catch (exception) {
      throw CoverdeReportTraceFileReadFailure.fromFileSystemException(
        traceFilePath: traceFilePath,
        exception: exception,
      );
    }
  }
  final document = CoverageDocument.parse(
    trace.toString(),
    traceModifiedAt: traceModifiedAt,
  );
  if (document.files.isEmpty) {
    throw CoverdeReportEmptyTraceFileFailure(
      traceFilePath: tracePaths.join(', '),
    );
  }
  return document;
}

String _absolute(String path) {
  final resolved = p.isAbsolute(path)
      ? path
      : p.join(Directory.current.path, path);
  return p.normalize(resolved);
}
