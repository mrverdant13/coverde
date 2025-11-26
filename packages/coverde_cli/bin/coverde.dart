import 'package:args/command_runner.dart';
import 'package:coverde/coverde.dart' show coverde;
import 'package:coverde/src/entities/coverde.exception.dart';
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> args) async {
  final logger = Logger();
  try {
    return await coverde(args: args, logger: logger);
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
