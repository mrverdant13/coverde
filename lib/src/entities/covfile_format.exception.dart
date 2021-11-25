import 'package:coverde/src/entities/coverde.exception.dart';
import 'package:io/io.dart';

/// {@template covfile_format_exception}
/// An exception that indicates that the coverage data of a given tested file is
/// not properly formatted.
/// {@endtemplate}
class CovfileFormatException extends CoverdeException {
  /// {@macro covfile_format_exception}
  CovfileFormatException({
    required this.message,
  });

  @override
  ExitCode get code => ExitCode.data;

  @override
  final String message;
}
