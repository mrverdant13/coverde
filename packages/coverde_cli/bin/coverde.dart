import 'package:args/command_runner.dart';
import 'package:coverde/coverde.dart' show coverde;
import 'package:coverde/src/entities/coverde.exception.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> arguments) async {
  try {
    return await coverde(arguments);
  } on UsageException catch (exception) {
    _logError(exception.message);
    stdout
      ..writeln()
      ..writeln(exception.usage)
      ..writeln();
    exit(ExitCode.usage.code);
  } on CoverdeException catch (exception) {
    _logError(exception.message);
    exit(exception.code.code);
  } catch (error, stackTrace) {
    _logError(error, stackTrace);
    exit(ExitCode.software.code);
  }
}

void _logError(Object error, [Object? stackTrace]) {
  stderr.writeln(
    wrapWith(
      error.toString(),
      [backgroundBlack, lightRed, styleBold],
    ),
  );
  if (stackTrace != null) {
    stderr.writeln(
      wrapWith(
        stackTrace.toString(),
        [backgroundBlack, lightRed],
      ),
    );
  }
}
