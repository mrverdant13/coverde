import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockPackageVersionManager extends Mock
    implements PackageVersionManager {}

void main() {
  group('$CoverdeCommandRunner', () {
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      packageVersionManager = _MockPackageVersionManager();
      when(() => packageVersionManager.logger).thenReturn(logger);
      cmdRunner = CoverdeCommandRunner(
        logger: logger,
        packageVersionManager: packageVersionManager,
      );
    });

    test('featureCommands', () {
      expect(
        cmdRunner.featureCommands,
        containsAll([
          isA<OptimizeTestsCommand>(),
          isA<CheckCommand>(),
          isA<FilterCommand>(),
          isA<ReportCommand>(),
          isA<RmCommand>(),
          isA<ValueCommand>(),
        ]),
      );
    });

    group('run', () {
      test(
        '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}'''
        'should not prompt for update',
        () async {
          await cmdRunner.run([
            '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}''',
            '--help',
          ]);
        },
      );

      test(
        '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.enabled.identifier}'''
        'should prompt for update',
        () async {
          when(() => packageVersionManager.promptUpdate())
              .thenAnswer((_) async {});
          await cmdRunner.run([
            '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.enabled.identifier}''',
            '--help',
          ]);
          verify(() => logger.level = Level.quiet).called(1);
          verify(() => packageVersionManager.promptUpdate()).called(1);
        },
      );

      test(
        '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.enabledVerbose.identifier}'''
        'should prompt for update with verbose level',
        () async {
          when(() => packageVersionManager.promptUpdate())
              .thenAnswer((_) async {});
          await cmdRunner.run([
            '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.enabledVerbose.identifier}''',
            '--help',
          ]);
          verify(() => logger.level = Level.verbose).called(1);
          verify(() => packageVersionManager.promptUpdate()).called(1);
        },
      );
    });
  });
}
