import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pub_score_checker/pub_score_checker.dart';

Future<void> main(List<String> arguments) async {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  final runner = PubScoreCheckerCommandRunner();
  await Future.wait([
    Logger.root.onRecord.forEach((record) {
      stdout.writeln(
        '[${record.level.name}] ${record.time}: ${record.message}',
      );
    }),
    runner.run(arguments),
  ]);
}
