import 'package:coverde/src/commands/commands.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeCommandRunner', () {
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      cmdRunner = CoverdeCommandRunner();
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
  });
}
