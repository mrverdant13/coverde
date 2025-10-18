import 'package:pub_score_checker/pub_score_checker.dart';

Future<void> main(List<String> arguments) async {
  final runner = PubScoreCheckerCommandRunner();
  await runner.run(arguments);
}
