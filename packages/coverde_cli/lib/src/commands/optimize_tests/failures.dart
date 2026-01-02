import 'package:coverde/coverde.dart';

/// {@template coverde_cli.optimize_tests_failure}
/// The interface for [OptimizeTestsCommand] failures.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsFailure extends CoverdeFailure {
  /// {@macro coverde_cli.optimize_tests_failure}
  const CoverdeOptimizeTestsFailure();
}

/// {@template coverde_cli.optimize_tests_invalid_input_failure}
/// The interface for [OptimizeTestsCommand] failures that indicates that an
/// invalid input was provided.
/// {@endtemplate}
sealed class CoverdeOptimizeTestsInvalidInputFailure
    extends CoverdeOptimizeTestsFailure {
  /// {@macro coverde_cli.optimize_tests_invalid_input_failure}
  const CoverdeOptimizeTestsInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [OptimizeTestsCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.optimize_tests_pubspec_not_found_failure}
/// A [OptimizeTestsCommand] failure that indicates that the pubspec.yaml file
/// was not found.
/// {@endtemplate}
final class CoverdeOptimizeTestsPubspecNotFoundFailure
    extends CoverdeOptimizeTestsInvalidInputFailure {
  /// {@macro coverde_cli.optimize_tests_pubspec_not_found_failure}
  const CoverdeOptimizeTestsPubspecNotFoundFailure({
    required super.usageMessage,
    required this.projectDirPath,
  }) : super(
          invalidInputDescription:
              'No pubspec.yaml file found in $projectDirPath.',
        );

  /// The project directory path.
  final String projectDirPath;
}
