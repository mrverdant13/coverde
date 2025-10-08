import 'dart:async';
import 'dart:io';

import 'package:pana/pana.dart';

const defaultHostedUrl = 'https://pub.dev';

Future<void> main(List<String> args) async {
  final packagePath = () {
    final rawPath = args.firstOrNull;
    if (rawPath == null) {
      stderr.writeln('❌ No package path provided.');
      exit(1);
    }
    final packageDir = Directory(rawPath);
    if (!packageDir.existsSync()) {
      stderr.writeln('❌ Package path does not exist: <${packageDir.path}>.');
      exit(1);
    }
    return packageDir.resolveSymbolicLinksSync();
  }();
  final threshold = () {
    final rawThreshold = args.elementAtOrNull(1);
    if (rawThreshold == null) {
      stdout.writeln('⚠️ No exit code threshold provided. Using 0.');
      return 0;
    }
    final maybeThreshold = int.tryParse(rawThreshold);
    if (maybeThreshold == null) {
      stderr.writeln('⚠️ Invalid threshold: <$rawThreshold>. Using 0.');
      return 0;
    }
    return maybeThreshold.isNegative ? 0 : maybeThreshold;
  }();
  final tempDir = Directory.systemTemp
      .createTempSync('pana.${DateTime.now().millisecondsSinceEpoch}.');
  final tempPath = await tempDir.resolveSymbolicLinks();
  try {
    stdout
      ..writeln('🔍 Analyzing pub score ($threshold points of tolerance)...')
      ..writeln('⏳ This may take a while...');
    const pubHostedUrl = defaultHostedUrl;
    final toolEnv = await ToolEnvironment.create(
      pubCacheDir: tempPath,
      pubHostedUrl: pubHostedUrl,
    );
    final analyzer = PackageAnalyzer(
      toolEnv,
    );
    final options = InspectOptions(
      pubHostedUrl: pubHostedUrl,
    );
    try {
      final summary = await analyzer.inspectDir(packagePath, options: options);
      final report = summary.report;
      if (report == null) throw Exception('The report could not be generated.');
      var allPubPointsGranted = true;
      for (final s in report.sections) {
        final allSectionPointsGranted = s.grantedPoints == s.maxPoints;
        if (allSectionPointsGranted) continue;
        stdout
          ..writeln()
          ..writeln('=' * 80)
          ..writeln()
          ..writeln('🚩 ${s.title} (${s.grantedPoints} / ${s.maxPoints})')
          ..writeln(s.summary);
        allPubPointsGranted = false;
      }
      if (!allPubPointsGranted) {
        stdout
          ..writeln()
          ..writeln('=' * 80);
      }
      final grantedPoints = report.grantedPoints;
      final maxPoints = report.maxPoints;
      final difference = maxPoints - grantedPoints;
      stdout
        ..writeln()
        ..writeln('📃 POINTS: $grantedPoints/$maxPoints.');
      if (difference > threshold) {
        stderr.writeln('❌ The package score is below the threshold.');
        exitCode = 1;
      } else {
        stdout.writeln('✅ The package score is within the tolerance range.');
      }
    } on Object catch (e) {
      stderr
        ..writeln('❌ Problem analyzing the package.')
        ..writeln(e);
      exitCode = 1;
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
