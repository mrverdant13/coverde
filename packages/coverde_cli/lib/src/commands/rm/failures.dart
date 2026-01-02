import 'package:coverde/coverde.dart';

/// {@template coverde_cli.rm_failure}
/// The interface for [RmCommand] failures.
/// {@endtemplate}
sealed class CoverdeRmFailure extends CoverdeFailure {
  /// {@macro coverde_cli.rm_failure}
  const CoverdeRmFailure();
}

/// {@template coverde_cli.rm_invalid_input_failure}
/// The interface for [RmCommand] failures that indicates that an invalid
/// input was provided.
/// {@endtemplate}
sealed class CoverdeRmInvalidInputFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_invalid_input_failure}
  const CoverdeRmInvalidInputFailure({
    required this.invalidInputDescription,
    required this.usageMessage,
  });

  /// The description of the invalid input.
  final String invalidInputDescription;

  /// The [RmCommand] usage message.
  final String usageMessage;

  @override
  String get readableMessage => '''
$invalidInputDescription

$usageMessage
''';
}

/// {@template coverde_cli.rm_missing_paths_failure}
/// A [RmCommand] failure that indicates that no paths were provided.
/// {@endtemplate}
final class CoverdeRmMissingPathsFailure extends CoverdeRmInvalidInputFailure {
  /// {@macro coverde_cli.rm_missing_paths_failure}
  const CoverdeRmMissingPathsFailure({
    required super.usageMessage,
  }) : super(
          invalidInputDescription:
              'A set of file and/or directory paths should be provided.',
        );
}

/// {@template coverde_cli.rm_element_not_found_failure}
/// A [RmCommand] failure that indicates that an element was not found when
/// absence is not accepted.
/// {@endtemplate}
final class CoverdeRmElementNotFoundFailure extends CoverdeRmFailure {
  /// {@macro coverde_cli.rm_element_not_found_failure}
  const CoverdeRmElementNotFoundFailure({
    required this.elementPath,
  });

  /// The path to the element that was not found.
  final String elementPath;

  @override
  String get readableMessage => 'The <$elementPath> element does not exist.';
}
