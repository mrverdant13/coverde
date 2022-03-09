import 'package:coverde/src/entities/tracefile.dart';
import 'package:universal_io/io.dart';

/// {@template report_generator_base}
/// An instance the base information for report generation.
/// {@endtemplate}
abstract class ReportGeneratorBase {
  /// Name of the [tracefile] to be used for the report generation.
  String get tracefileName;

  /// Trace file to be used for the report generation.
  Tracefile get tracefile;

  /// Root folder of the tested project.
  Directory get projectRootDir => tracefile.asTree.source;

  /// [DateTime] of the last tracefile modification.
  DateTime get tracefileModificationDateTime;
}

/// Signature of the computation function for coverage HTML classes.
typedef CovClassSuffixBuilder = String Function(double coverage);
