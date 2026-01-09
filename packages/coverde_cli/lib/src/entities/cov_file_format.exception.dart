import 'package:coverde/src/entities/entities.dart';

/// {@template cov_file_format_failure}
/// A [CoverdeFailure] that indicates that the coverage data of a given tested
/// file is not properly formatted.
/// {@endtemplate}
class CovFileFormatFailure extends CoverdeFailure {
  /// {@macro cov_file_format_failure}
  const CovFileFormatFailure({
    required this.readableMessage,
  });

  @override
  final String readableMessage;
}
