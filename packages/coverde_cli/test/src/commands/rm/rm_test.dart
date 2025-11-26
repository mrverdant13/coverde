import 'package:args/command_runner.dart';
import 'package:coverde/src/commands/rm/rm.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../../../utils/mocks.dart';

void main() {
  group(
    'coverde rm',
    () {
      late CommandRunner<void> cmdRunner;
      late Logger logger;
      late RmCommand rmCmd;

      setUp(
        () {
          cmdRunner = CommandRunner<void>('test', 'A tester command runner');
          logger = MockLogger();
          rmCmd = RmCommand(logger: logger);
          cmdRunner.addCommand(rmCmd);
        },
      );

      tearDown(
        () {
          verifyNoMoreInteractions(logger);
        },
      );

      test(
        '| description',
        () {
          const expected = '''
Remove a set of files and folders.
''';

          final result = rmCmd.description;

          expect(result.trim(), expected.trim());
        },
      );

      test(
        '<existing_file> '
        '| previews deletion in dry-run mode (default)',
        () async {
          final filePath = path.joinAll(['coverage', 'existing.file']);
          final file = File(filePath);
          await file.create(recursive: true);
          expect(file.existsSync(), isTrue);

          await cmdRunner.run([
            rmCmd.name,
            filePath,
          ]);

          verify(
            () => logger.info('[DRY RUN] Would remove file: <$filePath>'),
          ).called(1);
          expect(file.existsSync(), isTrue);
        },
      );

      test(
        '--no-${RmCommand.dryRunFlag} '
        '<existing_file> '
        '| removes existing file when dry-run is disabled',
        () async {
          final filePath = path.joinAll(['coverage', 'existing.file']);
          final file = File(filePath);
          await file.create(recursive: true);
          expect(file.existsSync(), isTrue);

          await cmdRunner.run([
            rmCmd.name,
            '--no-${RmCommand.dryRunFlag}',
            filePath,
          ]);

          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '--no-${RmCommand.acceptAbsenceFlag} '
        '<non-existing_file> '
        '| fails when file does not exist',
        () async {
          final filePath = path.joinAll(['coverage', 'non-existing.file']);
          final file = File(filePath);
          expect(file.existsSync(), isFalse);

          Future<void> action() => cmdRunner.run([
                rmCmd.name,
                filePath,
                '--no-${RmCommand.acceptAbsenceFlag}',
              ]);

          expect(action, throwsA(isA<UsageException>()));
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '--${RmCommand.dryRunFlag} '
        '<existing_file> '
        '| explicitly enables dry-run mode',
        () async {
          final filePath = path.joinAll(['coverage', 'existing.file']);
          final file = File(filePath);
          await file.create(recursive: true);
          expect(file.existsSync(), isTrue);

          await cmdRunner.run([
            rmCmd.name,
            '--${RmCommand.dryRunFlag}',
            filePath,
          ]);

          verify(
            () => logger.info('[DRY RUN] Would remove file: <$filePath>'),
          ).called(1);
          expect(file.existsSync(), isTrue);
        },
      );

      test(
        '--${RmCommand.acceptAbsenceFlag} '
        '<non-existing_file> '
        '| shows message when file does not exist',
        () async {
          final filePath = path.joinAll(['coverage', 'non-existing.file']);
          final file = File(filePath);
          expect(file.existsSync(), isFalse);

          await cmdRunner.run([
            rmCmd.name,
            filePath,
            '--${RmCommand.acceptAbsenceFlag}',
          ]);

          verify(
            () => logger.info('The <$filePath> element does not exist.'),
          ).called(1);
          expect(file.existsSync(), isFalse);
        },
      );

      test(
        '<existing_directory> '
        '| previews deletion in dry-run mode (default)',
        () async {
          final dirPath = path.joinAll(['coverage', 'existing.dir']);
          final dir = Directory(dirPath);
          await dir.create(recursive: true);
          expect(dir.existsSync(), isTrue);

          await cmdRunner.run([
            rmCmd.name,
            dirPath,
          ]);

          verify(
            () => logger.info('[DRY RUN] Would remove dir:  <$dirPath>'),
          ).called(1);
          expect(dir.existsSync(), isTrue);
        },
      );

      test(
        '--no-${RmCommand.dryRunFlag} '
        '<existing_directory> '
        '| removes existing directory when dry-run is disabled',
        () async {
          final dirPath = path.joinAll(['coverage', 'existing.dir']);
          final dir = Directory(dirPath);
          await dir.create(recursive: true);
          expect(dir.existsSync(), isTrue);

          await cmdRunner.run([
            rmCmd.name,
            '--no-${RmCommand.dryRunFlag}',
            dirPath,
          ]);

          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '--no-${RmCommand.acceptAbsenceFlag} '
        '<non-existing_directory> '
        '| fails when directory does not exist',
        () async {
          final dirPath = path.joinAll(['coverage', 'non-existing.dir']);
          final dir = File(dirPath);
          expect(dir.existsSync(), isFalse);

          Future<void> action() => cmdRunner.run([
                rmCmd.name,
                dirPath,
                '--no-${RmCommand.acceptAbsenceFlag}',
              ]);

          expect(action, throwsA(isA<UsageException>()));
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '--${RmCommand.acceptAbsenceFlag} '
        '<non-existing_directory> '
        '| shows message when directory does not exist',
        () async {
          final dirPath = path.joinAll(['coverage', 'non-existing.dir']);
          final dir = File(dirPath);
          expect(dir.existsSync(), isFalse);

          await cmdRunner.run([
            rmCmd.name,
            dirPath,
            '--${RmCommand.acceptAbsenceFlag}',
          ]);

          verify(
            () => logger.info('The <$dirPath> element does not exist.'),
          ).called(1);
          expect(dir.existsSync(), isFalse);
        },
      );

      test(
        '| fails when no elements to remove',
        () {
          Future<void> action() => cmdRunner.run([rmCmd.name]);

          expect(action, throwsA(isA<UsageException>()));
        },
      );
    },
  );
}
