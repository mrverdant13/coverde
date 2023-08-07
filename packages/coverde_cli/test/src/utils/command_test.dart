import 'package:args/command_runner.dart';
import 'package:coverde/src/utils/command.dart';
import 'package:test/test.dart';

class FakeCmd extends Command<void> {
  FakeCmd() {
    argParser
      ..addOption('optionKey')
      ..addFlag('flagKey', defaultsTo: null);
  }

  @override
  String get description => 'fake command';

  @override
  String get name => 'fake';

  @override
  Future<void> run() async {}
}

void main() {
  group(
    '''

GIVEN a command''',
    () {
      late CommandRunner<void> cmdRunner;
      late Command cmd;

      // ARRANGE
      setUp(
        () {
          cmdRunner = CommandRunner<void>('fake', 'fake command');
          cmd = FakeCmd();
          cmdRunner.addCommand(cmd);
        },
      );

      group(
        '''

AND no parsed argument results''',
        () {
          // ARRANGE
          setUp(
            () {
              expect(cmd.argResults, isNull);
            },
          );

          test(
            '''

WHEN an option is checked
THEN an exception should be thrown
''',
            () {
              // ACT
              String action() => cmd.checkOption(
                    optionKey: 'optionKey',
                    optionName: 'optionName',
                  );

              // ASSERT
              expect(action, throwsA(isA<UsageException>()));
            },
          );

          test(
            '''

WHEN a flag is checked
THEN an exception should be thrown
''',
            () {
              // ACT
              bool action() => cmd.checkFlag(
                    flagKey: 'flagKey',
                    flagName: 'flagName',
                  );

              // ASSERT
              expect(action, throwsA(isA<UsageException>()));
            },
          );
        },
      );

      group(
        '''

AND parsed argument results''',
        () {
          // ARRANGE
          setUp(
            () async {
              // Ensure arg results existence.
              await cmdRunner.run([cmd.name]);
              expect(cmd.argResults, isNotNull);
            },
          );

          test(
            '''

├─ THAT does not include an option (optionKey)
WHEN the option is checked
THEN an exception should be thrown
''',
            () {
              // ACT
              String action() => cmd.checkOption(
                    optionKey: 'optionKey',
                    optionName: 'optionName',
                  );

              // ASSERT
              expect(action, throwsA(isA<UsageException>()));
            },
          );

          test(
            '''

├─ THAT does not include a flag (flagKey)
WHEN the flag is checked
THEN an exception should be thrown
''',
            () {
              // ACT
              bool action() => cmd.checkFlag(
                    flagKey: 'flagKey',
                    flagName: 'flagName',
                  );

              // ASSERT
              expect(action, throwsA(isA<UsageException>()));
            },
          );
        },
      );

      test(
        '''

AND parsed argument results
├─ THAT includes an empty string option (optionKey)
WHEN the option is checked
THEN an exception should be thrown
''',
        () async {
          // ARRANGE
          await cmdRunner.run([
            cmd.name,
            '--optionKey',
            '',
          ]);
          expect(cmd.argResults, isNotNull);

          // ACT
          String action() => cmd.checkOption(
                optionKey: 'optionKey',
                optionName: 'optionName',
              );

          // ASSERT
          expect(action, throwsA(isA<UsageException>()));
        },
      );

      test(
        '''

AND invalid coverage percentage values
WHEN the coverage values are checked
THEN exceptions should be thrown''',
        () {
          // ARRANGE
          const invalidCovValues = [-3, -1.3, 101, 103.6];

          // ACT
          for (final invalidCovValue in invalidCovValues) {
            num action() => cmd.checkCoverage(
                  coverage: invalidCovValue,
                  valueName: 'coverageName',
                );

            // ASSERT
            expect(action, throwsA(isA<UsageException>()));
          }
        },
      );
    },
  );
}
