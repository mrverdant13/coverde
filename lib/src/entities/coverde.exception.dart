import 'package:io/io.dart';

/// {@template coverde_exception}
/// The interface for `coverde` exceptions.
/// {@endtemplate}
abstract class CoverdeException implements Exception {
  /// {@macro coverde_exception}
  const CoverdeException();

  /// Termination code for the current execution.
  ExitCode get code;

  /// Termination message.
  String get message;

  @override
  String toString() => message;
}
