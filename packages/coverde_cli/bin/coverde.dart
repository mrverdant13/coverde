import 'package:args/command_runner.dart';
import 'package:coverde/coverde.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> args) async {
  final logger = Logger();
  final httpClient = http.Client();
  try {
    return await coverde(
      args: args,
      logger: logger,
      globalLockFilePath:
          Platform.script.resolve('../pubspec.lock').toFilePath(),
      pubApiBaseUrl: 'https://pub.dev',
      httpClient: httpClient,
      rawDartVersion: Platform.version,
    );
  } on CoverdeFailure catch (failure) {
    _logError(logger, failure.readableMessage);
    exit(failure.exitCode.code);
  } on UsageException catch (exception) {
    _logError(logger, exception.message);
    logger
      ..info('')
      ..info(exception.usage)
      ..info('');
    exit(ExitCode.usage.code);
  } on Object catch (error, stackTrace) {
    _logError(logger, error, stackTrace);
    exit(ExitCode.software.code);
  } finally {
    httpClient.close();
  }
}

void _logError(
  Logger logger,
  Object error, [
  Object? stackTrace,
]) {
  logger.err(
    wrapWith(
      error.toString(),
      [lightRed, styleBold],
    ),
  );
  if (stackTrace != null) {
    logger.err(
      wrapWith(
        stackTrace.toString(),
        [lightRed],
      ),
    );
  }
}

extension on CoverdeFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeCheckFailure failure => failure.exitCode,
        final CoverdeFilterFailure failure => failure.exitCode,
        final CoverdeOptimizeTestsFailure failure => failure.exitCode,
        final CoverdeReportFailure failure => failure.exitCode,
        final CoverdeRmFailure failure => failure.exitCode,
        final CoverdeValueFailure failure => failure.exitCode,
        _ => ExitCode.software,
      };
}

extension on CoverdeCheckFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeCheckInvalidInputFailure failure => failure.exitCode,
        final CoverdeCheckInvalidTraceFileFailure failure => failure.exitCode,
        CoverdeCheckCoverageBelowMinimumFailure() => ExitCode.data,
      };
}

extension on CoverdeCheckInvalidInputFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeCheckMoreThanOneArgumentFailure() ||
        CoverdeCheckMissingMinimumCoverageThresholdFailure() ||
        CoverdeCheckInvalidMinimumCoverageThresholdFailure() =>
          ExitCode.usage,
      };
}

extension on CoverdeCheckInvalidTraceFileFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeCheckTraceFileNotFoundFailure() => ExitCode.noInput,
        CoverdeCheckEmptyTraceFileFailure() => ExitCode.data,
        CoverdeCheckTraceFileReadFailure() => ExitCode.ioError,
      };
}

extension on CoverdeFilterFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeFilterInvalidInputFailure failure => failure.exitCode,
        CoverdeFilterTraceFileNotFoundFailure() => ExitCode.noInput,
        CoverdeFilterTraceFileReadFailure() => ExitCode.ioError,
        final CoverdeFilterFileOperationFailure failure => failure.exitCode,
        final CoverdeFilterDirectoryOperationFailure failure =>
          failure.exitCode,
      };
}

extension on CoverdeFilterFileOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeFilterFileWriteFailure() => ExitCode.ioError,
      };
}

extension on CoverdeFilterDirectoryOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeFilterDirectoryCreateFailure() => ExitCode.ioError,
      };
}

extension on CoverdeFilterInvalidInputFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeFilterInvalidRegexPatternFailure() => ExitCode.usage,
      };
}

extension on CoverdeOptimizeTestsFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeOptimizeTestsInvalidInputFailure failure =>
          failure.exitCode,
        final CoverdeOptimizeTestsFileOperationFailure failure =>
          failure.exitCode,
        final CoverdeOptimizeTestsDirectoryOperationFailure failure =>
          failure.exitCode,
      };
}

extension on CoverdeOptimizeTestsFileOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeOptimizeTestsFileReadFailure() ||
        CoverdeOptimizeTestsFileWriteFailure() ||
        CoverdeOptimizeTestsFileDeleteFailure() =>
          ExitCode.ioError,
      };
}

extension on CoverdeOptimizeTestsDirectoryOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeOptimizeTestsDirectoryListFailure() ||
        CoverdeOptimizeTestsDirectoryCreateFailure() =>
          ExitCode.ioError,
      };
}

extension on CoverdeOptimizeTestsInvalidInputFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeOptimizeTestsPubspecNotFoundFailure() => ExitCode.noInput,
      };
}

extension on CoverdeReportFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeReportInvalidInputFailure failure => failure.exitCode,
        final CoverdeReportInvalidTraceFileFailure failure => failure.exitCode,
        final CoverdeReportFileOperationFailure failure => failure.exitCode,
      };
}

extension on CoverdeReportFileOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeReportFileReadFailure() ||
        CoverdeReportFileWriteFailure() ||
        CoverdeReportFileCreateFailure() =>
          ExitCode.ioError,
      };
}

extension on CoverdeReportInvalidInputFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeReportInvalidMediumThresholdFailure() ||
        CoverdeReportInvalidHighThresholdFailure() ||
        CoverdeReportInvalidThresholdRelationshipFailure() =>
          ExitCode.usage,
      };
}

extension on CoverdeReportInvalidTraceFileFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeReportTraceFileNotFoundFailure() => ExitCode.noInput,
        CoverdeReportEmptyTraceFileFailure() => ExitCode.data,
        CoverdeReportTraceFileReadFailure() => ExitCode.ioError,
      };
}

extension on CoverdeRmFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeRmInvalidInputFailure failure => failure.exitCode,
        CoverdeRmElementNotFoundFailure() => ExitCode.noInput,
        final CoverdeRmFileOperationFailure failure => failure.exitCode,
        final CoverdeRmDirectoryOperationFailure failure => failure.exitCode,
      };
}

extension on CoverdeRmFileOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeRmFileDeleteFailure() => ExitCode.ioError,
      };
}

extension on CoverdeRmDirectoryOperationFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeRmDirectoryDeleteFailure() => ExitCode.ioError,
      };
}

extension on CoverdeRmInvalidInputFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeRmMissingPathsFailure() => ExitCode.usage,
      };
}

extension on CoverdeValueFailure {
  ExitCode get exitCode => switch (this) {
        final CoverdeValueInvalidTraceFileFailure failure => failure.exitCode,
        CoverdeValueFileReadFailure() => ExitCode.ioError,
      };
}

extension on CoverdeValueInvalidTraceFileFailure {
  ExitCode get exitCode => switch (this) {
        CoverdeValueTraceFileNotFoundFailure() => ExitCode.noInput,
        CoverdeValueEmptyTraceFileFailure() => ExitCode.data,
        CoverdeValueTraceFileReadFailure() => ExitCode.ioError,
      };
}
