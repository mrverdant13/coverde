import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:pana/pana.dart';

const defaultHostedUrl = 'https://pub.dev';

class PubScoreCheckerCommandRunner extends CommandRunner<void> {
  PubScoreCheckerCommandRunner()
      : super(
          'pub_score_checker',
          'Check the pub score of a package',
        ) {
    addCommand(CheckPubScoreCommand());
  }
}

final class CheckPubScoreCommand extends Command<void> {
  CheckPubScoreCommand() {
    addSubcommand(LocalCommand());
    addSubcommand(RemoteCommand());
  }

  @override
  String get description => 'Check the pub score of a package';

  @override
  String get name => 'check_pub_score';
}

abstract class PubScoreCheckerCommand extends Command<void> {
  PubScoreCheckerCommand() : super() {
    argParser
      ..addOption(
        'threshold',
        help: 'The threshold for the pub score.',
        mandatory: true,
      )
      ..addOption(
        'markdown-output',
        help: 'The file to write the markdown output to.',
      );
  }

  Future<void> report(
    Future<Summary> Function(
      PackageAnalyzer analyzer,
      InspectOptions options,
    ) inspect,
  ) async {
    final argResults = this.argResults!;
    final rawThreshold = argResults.option('threshold')!;
    final threshold = int.tryParse(rawThreshold);
    if (threshold == null) {
      throw Exception('Invalid threshold: <$rawThreshold>.');
    }
    final markdownOutputFilePath = argResults.option('markdown-output');
    final markdownBuffer = StringBuffer();

    final tempDir = Directory.systemTemp
        .createTempSync('pana.${DateTime.now().millisecondsSinceEpoch}.');
    final tempPath = await tempDir.resolveSymbolicLinks();
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

    stdout
      ..writeln('🔍 Analyzing pub score ($threshold points of tolerance)...')
      ..writeln('⏳ This may take a while...');

    final summary = await inspect(analyzer, options);
    final report = summary.report;
    if (report == null) throw Exception('The report could not be generated.');
    if (report.grantedPoints != report.maxPoints) stdout.writeln();
    for (final s in report.sections) {
      final allSectionPointsGranted = s.grantedPoints == s.maxPoints;
      if (allSectionPointsGranted) continue;
      stdout.writeln('🚩 ${s.title} (${s.grantedPoints} / ${s.maxPoints})');
      markdownBuffer
        ..writeln('## [x] ${s.grantedPoints} / ${s.maxPoints}: ${s.title}')
        ..writeln(s.summary);
    }
    final grantedPoints = report.grantedPoints;
    final maxPoints = report.maxPoints;
    final difference = maxPoints - grantedPoints;
    stdout
      ..writeln()
      ..writeln('📃 POINTS: $grantedPoints/$maxPoints.');
    if (markdownOutputFilePath != null) {
      File(markdownOutputFilePath).writeAsStringSync(markdownBuffer.toString());
    }
    if (difference > threshold) {
      stderr.writeln('❌ The package score is below the threshold.');
      exitCode = 1;
    } else {
      stdout.writeln('✅ The package score is within the tolerance range.');
    }
  }
}

class RemoteCommand extends PubScoreCheckerCommand {
  RemoteCommand() {
    argParser.addOption(
      'package-name',
      help: 'The name of the package to check.',
      mandatory: true,
    );
  }

  @override
  String get name => 'remote';

  @override
  String get description =>
      'Check the pub score of a package available on Pub.dev.';

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final packageName = argResults.option('package-name')!;
    await super.report((analyzer, options) async {
      return analyzer.inspectPackage(
        packageName,
        options: options,
      );
    });
  }
}

class LocalCommand extends PubScoreCheckerCommand {
  LocalCommand() {
    argParser.addOption(
      'package-path',
      help: 'The path to the package to check.',
      mandatory: true,
    );
  }

  @override
  String get name => 'local';

  @override
  String get description =>
      'Check the pub score of a package available locally.';

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final packagePath = argResults.option('package-path')!;
    await super.report((analyzer, options) async {
      return analyzer.inspectDir(
        packagePath,
        options: options,
      );
    });
  }
}
