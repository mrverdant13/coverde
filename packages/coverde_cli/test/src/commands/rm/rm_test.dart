import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockPackageVersionManager extends Mock
    implements PackageVersionManager {}

final class _FakeCoverdeCommandRunner extends CoverdeCommandRunner {
  _FakeCoverdeCommandRunner({
    required super.logger,
    required super.packageVersionManager,
  });

  @override
  Future<void> run(Iterable<String> args) {
    return super.run([
      ...args,
      '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}''',
    ]);
  }
}

void main() {
  group('coverde rm', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(
      () {
        logger = _MockLogger();
        packageVersionManager = _MockPackageVersionManager();
        cmdRunner = _FakeCoverdeCommandRunner(
          logger: logger,
          packageVersionManager: packageVersionManager,
        );
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

        final result = RmCommand().description;

        expect(result.trim(), expected.trim());
      },
    );

    test(
      '<existing_file> '
      '| previews deletion in dry-run mode (default)',
      () async {
        final filePath = p.joinAll(['coverage', 'existing.file']);
        final file = File(filePath);
        await file.create(recursive: true);
        expect(file.existsSync(), isTrue);

        await cmdRunner.run([
          'remove',
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
        final filePath = p.joinAll(['coverage', 'existing.file']);
        final file = File(filePath);
        await file.create(recursive: true);
        expect(file.existsSync(), isTrue);

        await cmdRunner.run([
          'remove',
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
        final filePath = p.joinAll(['coverage', 'non-existing.file']);
        final file = File(filePath);
        expect(file.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              'remove',
              filePath,
              '--no-${RmCommand.acceptAbsenceFlag}',
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeRmElementNotFoundFailure>().having(
              (e) => e.elementPath,
              'elementPath',
              filePath,
            ),
          ),
        );
        expect(file.existsSync(), isFalse);
      },
    );

    test(
      '--${RmCommand.dryRunFlag} '
      '<existing_file> '
      '| explicitly enables dry-run mode',
      () async {
        final filePath = p.joinAll(['coverage', 'existing.file']);
        final file = File(filePath);
        await file.create(recursive: true);
        expect(file.existsSync(), isTrue);

        await cmdRunner.run([
          'remove',
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
        final filePath = p.joinAll(['coverage', 'non-existing.file']);
        final file = File(filePath);
        expect(file.existsSync(), isFalse);

        await cmdRunner.run([
          'remove',
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
        final dirPath = p.joinAll(['coverage', 'existing.dir']);
        final dir = Directory(dirPath);
        await dir.create(recursive: true);
        expect(dir.existsSync(), isTrue);

        await cmdRunner.run([
          'remove',
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
        final dirPath = p.joinAll(['coverage', 'existing.dir']);
        final dir = Directory(dirPath);
        await dir.create(recursive: true);
        expect(dir.existsSync(), isTrue);

        await cmdRunner.run([
          'remove',
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
        final dirPath = p.joinAll(['coverage', 'non-existing.dir']);
        final dir = File(dirPath);
        expect(dir.existsSync(), isFalse);

        Future<void> action() => cmdRunner.run([
              'remove',
              dirPath,
              '--no-${RmCommand.acceptAbsenceFlag}',
            ]);

        expect(
          action,
          throwsA(
            isA<CoverdeRmElementNotFoundFailure>().having(
              (e) => e.elementPath,
              'elementPath',
              dirPath,
            ),
          ),
        );
        expect(dir.existsSync(), isFalse);
      },
    );

    test(
      '--${RmCommand.acceptAbsenceFlag} '
      '<non-existing_directory> '
      '| shows message when directory does not exist',
      () async {
        final dirPath = p.joinAll(['coverage', 'non-existing.dir']);
        final dir = File(dirPath);
        expect(dir.existsSync(), isFalse);

        await cmdRunner.run([
          'remove',
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
        Future<void> action() => cmdRunner.run([
              'remove',
            ]);

        expect(
          action,
          throwsA(isA<CoverdeRmMissingPathsFailure>()),
        );
      },
    );
  });
}
