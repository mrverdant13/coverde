import 'package:args/args.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/console/render_console.dart';
import 'package:coverde/src/features/reporting/reporters/coverage_source_reader.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// {@template console_cmd}
/// A command to print the coverage value of one or more trace files.
/// {@endtemplate}
class ConsoleCommand extends CoverdeCommand {
  /// {@macro console_cmd}
  ConsoleCommand() {
    argParser
      ..addMultiOption(
        inputOption,
        abbr: inputOption[0],
        help: '''
Coverage trace file used to compute the coverage value.

Repeat to merge traces. Records with the same path are merged.''',
        valueHelp: _inputHelpValue,
        defaultsTo: const ['coverage/lcov.info'],
      )
      ..addOption(
        fileCoverageLogLevelFlag,
        help: '''
The log level for the coverage value for each source file listed in the $_inputHelpValue info file.''',
        allowed: FileCoverageLogLevel.values.map((level) => level.identifier),
        allowedHelp: {
          for (final logLevel in FileCoverageLogLevel.values)
            logLevel.identifier: logLevel.help,
        },
        defaultsTo: FileCoverageLogLevel.lineContent.identifier,
      );
  }

  static const _inputHelpValue = 'LCOV_FILE';

  /// Option name for the trace files whose coverage value should be computed.
  @visibleForTesting
  static const inputOption = 'input';

  /// Option name for the log level for the coverage value for each source file.
  @visibleForTesting
  static const fileCoverageLogLevelFlag = 'file-coverage-log-level';

  @override
  String get description => '''
Print the coverage value (%) of one or more trace files.

Print the coverage value of the $_inputHelpValue info files.''';

  @override
  String get name => 'console';

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final level = _level(argResults);
    final tracePaths = [
      for (final tracePath in argResults.multiOption(inputOption))
        _absolute(tracePath),
    ];
    final document = _document(tracePaths);
    if (level == ConsoleReportLevel.lineContent) {
      _readUncoveredSources(document);
    }
    final report = await renderConsoleReport(
      document: document,
      sources: const _AbsoluteCoverageSourceReader(),
      level: level,
    );
    logger.write(report);
  }

  ConsoleReportLevel _level(ArgResults argResults) {
    final rawLevel = argResults.option(fileCoverageLogLevelFlag);
    return ConsoleReportLevel.values.firstWhere(
      // The args parser already rejected identifiers outside this set.
      (level) => level.identifier == rawLevel,
    );
  }

  CoverageDocument _document(List<String> tracePaths) {
    final trace = StringBuffer();
    DateTime? traceModifiedAt;
    for (final traceFilePath in tracePaths) {
      if (!FileSystemEntity.isFileSync(traceFilePath)) {
        throw CoverdeReportTraceFileNotFoundFailure(
          traceFilePath: traceFilePath,
        );
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

  void _readUncoveredSources(CoverageDocument document) {
    for (final file in document.files) {
      if (file.lines.every((line) => line.hasBeenHit)) continue;
      if (!hostCanResolveCoveragePath(
        file.path,
        windowsHost: Platform.isWindows,
      )) {
        throw CoverdeReportUnresolvedCoveragePathFailure(sourcePath: file.path);
      }
      final source = File(file.path).absolute;
      try {
        source.readAsLinesSync();
      } on FileSystemException catch (exception) {
        throw CoverdeReportFileReadFailure.fromFileSystemException(
          filePath: source.path,
          exception: exception,
        );
      }
    }
  }

  String _absolute(String value) {
    final resolved = path.isAbsolute(value)
        ? value
        : path.join(Directory.current.path, value);
    return path.normalize(resolved);
  }
}

/// Reads source through [Directory.current], matching `coverde value`.
final class _AbsoluteCoverageSourceReader implements CoverageSourceReader {
  const _AbsoluteCoverageSourceReader();

  @override
  List<String>? readLines(String sourcePath) {
    return const FileCoverageSourceReader().readLines(
      File(sourcePath).absolute.path,
    );
  }
}
