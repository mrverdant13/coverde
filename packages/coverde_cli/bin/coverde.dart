import 'package:args/command_runner.dart';
import 'package:coverde/coverde.dart' show coverde;
import 'package:coverde/src/entities/coverde.exception.dart';
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
  } on UsageException catch (exception) {
    _logError(logger, exception.message);
    logger
      ..info('')
      ..info(exception.usage)
      ..info('');
    exit(ExitCode.usage.code);
  } on CoverdeException catch (exception) {
    _logError(logger, exception.message);
    exit(exception.code.code);
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
