import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/features/reporting/reporting.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

export 'failures.dart';

/// Overrides the terminal width. Tests set this because a test process has
/// no terminal.
@visibleForTesting
int? debugReportColumns;

/// Whether a printed report should emit ANSI color.
///
/// A report written to a file stays plain. [printing] is false in that case.
bool reportColor({required bool printing}) {
  if (!printing) return false;
  final override = debugReportColor;
  if (override != null) return override;
  // A test process has no terminal, so ANSI support is not read in tests.
  // coverage:ignore-start
  if (stdout.hasTerminal && stdout.supportsAnsiEscapes) return true;
  // coverage:ignore-end
  return false;
}

/// Overrides color for tests. A test process has no terminal.
@visibleForTesting
bool? debugReportColor;

bool _printing(ReportDefinition definition) {
  return switch (definition) {
    ConsoleReportDefinition(:final destination) => destination == null,
    FilesReportDefinition() => false,
  };
}

/// The terminal width, or 80 when stdout is not a terminal.
int reportColumns() {
  final override = debugReportColumns;
  if (override != null) return override;
  // A test process has no terminal, so this width is not read in tests.
  // coverage:ignore-start
  if (stdout.hasTerminal) return stdout.terminalColumns;
  // coverage:ignore-end
  return 80;
}

/// {@template render_cmd}
/// A command to render a named coverage report.
/// {@endtemplate}
class RenderCommand extends CoverdeCommand {
  /// {@macro render_cmd}
  RenderCommand() {
    argParser
      ..addOption(
        inputOption,
        abbr: inputOption[0],
        help: 'Coverage trace file to render.',
        valueHelp: _inputHelpValue,
        defaultsTo: 'coverage/lcov.info',
      )
      ..addOption(
        reportOption,
        abbr: reportOption[0],
        help: '''
Name of the report defined in coverde.yaml.

Required when coverde.yaml defines more than one report.
When it defines one report, that report is used.''',
        valueHelp: _reportHelpValue,
      )
      ..addMultiOption(
        variableOption,
        abbr: 'D',
        help: '''
A name=value pair exposed to the template as variables["name"].

Repeat to set more than one variable. A later copy of the same name wins.''',
        valueHelp: _variableHelpValue,
        defaultsTo: const [],
      );
  }

  static const _configFileName = 'coverde.yaml';
  static const _inputHelpValue = 'TRACE_FILE';
  static const _reportHelpValue = 'REPORT';
  static const _variableHelpValue = 'NAME=VALUE';

  /// Option name for the origin trace file.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the report defined in coverde.yaml.
  @visibleForTesting
  static const reportOption = 'report';

  /// Option name for a template variable.
  @visibleForTesting
  static const variableOption = 'variable';

  @override
  String get description => '''
Render a named coverage report from a trace file.

The report is selected from the reports defined in $_configFileName.''';

  @override
  String get name => 'render';

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final traceFilePath = _absolute(argResults.option(inputOption)!);
    final variables = _variables(argResults.multiOption(variableOption));
    final configPath = p.normalize(
      p.join(Directory.current.path, _configFileName),
    );
    final definition = resolveReportDefinition(
      reports: parseReportDefinitions(
        _readConfig(configPath),
        baseDirectory: p.dirname(configPath),
      ),
      reportName: argResults.option(reportOption),
      configPath: configPath,
    );

    if (!FileSystemEntity.isFileSync(traceFilePath)) {
      throw CoverdeRenderTraceFileNotFoundFailure(traceFilePath: traceFilePath);
    }
    final traceFile = File(traceFilePath);
    final CoverageDocument document;
    try {
      final traceModifiedAt = traceFile.lastModifiedSync();
      document = await CoverageDocument.parseStreaming(
        traceFile,
        traceModifiedAt: traceModifiedAt,
      );
    } on FileSystemException catch (exception) {
      throw CoverdeRenderTraceFileReadFailure.fromFileSystemException(
        traceFilePath: traceFilePath,
        exception: exception,
      );
    }
    if (document.files.isEmpty) {
      throw CoverdeRenderEmptyTraceFileFailure(traceFilePath: traceFilePath);
    }

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
        color: reportColor(printing: _printing(definition)),
      ),
    );
    if (destination is ConsoleReportDestination) {
      final output = (definition as ConsoleReportDefinition).destination;
      if (output == null) {
        logger.write(buffer.toString());
      } else {
        final file = File(output);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(buffer.toString());
      }
    }
  }

  Map<String, String> _variables(List<String> entries) {
    final variables = <String, String>{};
    for (final entry in entries) {
      final separator = entry.indexOf('=');
      if (separator <= 0) {
        throw CoverdeRenderInvalidVariableFailure(
          rawValue: entry,
          usageMessage: usageWithoutDescription,
        );
      }
      variables[entry.substring(0, separator)] = entry.substring(separator + 1);
    }
    return variables;
  }

  String _readConfig(String configPath) {
    if (!FileSystemEntity.isFileSync(configPath)) return '';
    try {
      return File(configPath).readAsStringSync();
    } on FileSystemException catch (exception) {
      throw CoverdeRenderConfigFileReadFailure.fromFileSystemException(
        configPath: configPath,
        exception: exception,
      );
    }
  }

  String _absolute(String path) {
    final resolved = p.isAbsolute(path)
        ? path
        : p.join(Directory.current.path, path);
    return p.normalize(resolved);
  }
}
