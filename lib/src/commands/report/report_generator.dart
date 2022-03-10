import 'package:coverde/src/commands/report/dir_report_generator.dart';
import 'package:coverde/src/commands/report/file_report_generator.dart';
import 'package:coverde/src/commands/report/report_generator_base.dart';
import 'package:coverde/src/commands/report/report_stylesheet_generator.dart';
import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:universal_io/io.dart';

/// {@template report_generator}
/// A coverage report generator.
/// {@endtemplate}
class ReportGenerator extends ReportGeneratorBase
    with ReportStylesheetGenerator, DirReportGenerator, FileReportGenerator {
  /// {@macro report_generator}
  ReportGenerator({
    required this.tracefile,
    required this.tracefileName,
    required this.tracefileModificationDateTime,
  });

  @override
  final Tracefile tracefile;

  @override
  final String tracefileName;

  @override
  final DateTime tracefileModificationDateTime;

  /// Generate the coverage HTML report.
  void generate({
    required Directory outputDir,
    required double medium,
    required double high,
  }) {
    final projectRootCovDir = tracefile.asTree;

    String covClassSuffix(double coverage) {
      if (coverage < medium) return 'Lo';
      if (coverage < high) return 'Med';
      return 'Hi';
    }

    void generateSubReports({
      required CovDir covDir,
    }) {
      for (final element in covDir.elements) {
        if (element is CovFile) {
          generateFileReport(
            rootReportDir: outputDir,
            covFile: element,
            covClassSuffix: covClassSuffix,
          );
        } else if (element is CovDir) {
          generateDirReport(
            rootReportDir: outputDir,
            covDir: element,
            covClassSuffix: covClassSuffix,
          );
          generateSubReports(covDir: element);
        }
      }
    }

    generateStyleSheet(rootReportDir: outputDir);
    generateDirReport(
      rootReportDir: outputDir,
      covDir: projectRootCovDir,
      covClassSuffix: covClassSuffix,
    );
    generateSubReports(covDir: projectRootCovDir);
  }
}
