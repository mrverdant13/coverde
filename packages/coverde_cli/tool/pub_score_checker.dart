import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:io/io.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> args) async {
  final maxDiff = int.tryParse(args.firstOrNull ?? '') ?? 0;
  stdout.writeln('Analyzing pub score with `pana`...');
  final result = await Process.run(
    'pana',
    ['--no-warning', '--json', '.'],
    runInShell: true,
  );
  final resultString = result.stdout as String;
  final resultJson = jsonDecode(resultString) as Map<String, dynamic>;
  final scores = resultJson['scores'] as Map<String, dynamic>;
  final grantedPoints = scores['grantedPoints'] as int;
  final maxPoints = scores['maxPoints'] as int;
  final message = '''
MAX POINTS: $maxPoints
GRANTED POINTS: $grantedPoints''';
  if ((maxPoints - grantedPoints) > maxDiff) {
    final reportJson = resultJson['report'] as Map<String, dynamic>;
    final sectionsJsonList = reportJson['sections'] as List;
    for (final rawSection in sectionsJsonList) {
      final sectionJson = rawSection as Map<String, dynamic>;
      final title = sectionJson['title'] as String;
      final maxPoints = sectionJson['maxPoints'] as int;
      final grantedPoints = sectionJson['grantedPoints'] as int;
      if (maxPoints > grantedPoints) {
        stderr
          ..writeln('------------------------------------')
          ..writeln(title.toUpperCase())
          ..writeln('Max points: $maxPoints')
          ..writeln('Granted points: $grantedPoints')
          ..writeln(sectionJson['summary'] as String);
      }
    }
    stderr
      ..writeln('====================================')
      ..writeln(message);
    exit(ExitCode.software.code);
  }
  stdout.writeln(message);
}
