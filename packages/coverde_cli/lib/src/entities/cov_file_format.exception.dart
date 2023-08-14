import 'package:coverde/src/entities/coverde.exception.dart';
import 'package:io/io.dart';

/// {@template cov_file_format_exception}
/// An exception that indicates that the coverage data of a given tested file is
/// not properly formatted.
/// {@endtemplate}
class CovFileFormatException extends CoverdeException {
  /// {@macro cov_file_format_exception}
  CovFileFormatException({
    required this.message,
  });

  @override
  ExitCode get code => ExitCode.data;

  @override
  final String message;
}
