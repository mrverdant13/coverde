/// {@template coverde_cli.coverde_failure}
/// The interface for `coverde` failures.
/// {@endtemplate}
abstract class CoverdeFailure implements Exception {
  /// {@macro coverde_cli.coverde_failure}
  const CoverdeFailure();

  /// The readable message for the failure.
  String get readableMessage;
}
