import 'package:coverde/src/commands/report/report_generator_base.dart';
import 'package:coverde/src/entities/cov_base.dart';
import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:universal_io/io.dart';

/// Report generator for [CovDir]s.
mixin DirReportGenerator on ReportGeneratorBase {
  static const _subElementReportSegmentTemplateSource = '''
          <tr>
            <td class="coverFile">
              <a class="coverFileAnchor" href="{{{reportPath}}}">{{{elementPath}}}</a>
            </td>
            <td class="coverBar" align="center">
              <table
                class="barTable"
                width="100%"
                border="0"
                cellspacing="0"
                cellpadding="1"
              >
                <tbody>
                  <tr>
                    <td class="coverBarOutline">
                      <table
                        width="100%"
                        height="10"
                        border="0"
                        cellspacing="0"
                        cellpadding="0"
                      >
                        <tbody>
                          <tr>
                            {{#positiveCoverage}}<td width="{{{coverage}}}%" class="barCov barCov{{{covSuffix}}}"></td>
                            {{/positiveCoverage}}<td class="barBackground"></td>
                          </tr>
                        </tbody>
                      </table>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
            <td class="coverPer coverPer{{{covSuffix}}}">{{{coverage}}} %</td>
            <td class="coverNum coverNum{{{covSuffix}}}">{{{hitLines}}} / {{{foundLines}}}</td>
          </tr>''';

  static final _subElementReportSegmentTemplate = Template(
    _subElementReportSegmentTemplateSource,
  );

  static const _dirReportTemplateSource = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="stylesheet" type="text/css" href="{{{cssPath}}}" />
    <title class="headTitle">Coverage Report - {{{tracefileName}}}</title>
  </head>

  <body>
    <table width="100%" border="0" cellspacing="0" cellpadding="0">
      <tbody>
        <tr>
          <td class="title">Code Coverage Report</td>
        </tr>
        <tr>
          <td class="ruler" height="3px"></td>
        </tr>

        <tr>
          <td width="100%">
            <table cellpadding="1" border="0" width="100%">
              <tbody>
                <tr>
                  <td height="3px"></td>
                </tr>
                <tr>
                  <td width="10%" class="headerItem">Current view:</td>
                  <td width="35%" class="headerValue currentDirPath">
                    <a class="topLevelAnchor" href="{{{reportRoot}}}">top level</a> - {{{dirPath}}}
                  </td>
                  <td width="5%"></td>
                  <td width="15%"></td>
                  <td width="10%" class="headerCovTableHead">Hit</td>
                  <td width="10%" class="headerCovTableHead">Total</td>
                  <td width="15%" class="headerCovTableHead">Coverage</td>
                </tr>
                <tr>
                  <td class="headerItem">Test:</td>
                  <td class="headerValue tracefileName">{{{tracefileName}}}</td>
                  <td></td>
                  <td class="headerItem">Lines:</td>
                  <td class="headerCovTableEntry linesHit">{{{hitLines}}}</td>
                  <td class="headerCovTableEntry linesFound">{{{foundLines}}}</td>
                  <td class="covValue headerCovTableEntry{{{covSuffix}}}">{{{coverage}}} %</td>
                </tr>
                <tr>
                  <td class="headerItem">Date:</td>
                  <td class="headerValue lastTracefileModificationDate">
                    {{{date}}}
                  </td>
                  <td></td>
                  <td></td>
                  <td></td>
                  <td></td>
                  <td></td>
                </tr>
                <tr>
                  <td height="3px"></td>
                </tr>
              </tbody>
            </table>
          </td>
        </tr>

        <tr>
          <td class="ruler" height="3px"></td>
        </tr>
      </tbody>
    </table>
    <br />
    <center>
      <table width="80%" cellpadding="1" cellspacing="1" border="0">
        <tbody class="covTableBody">
          <tr>
            <td width="60%"></td>
            <td width="15%"></td>
            <td width="10%"></td>
            <td width="15%"></td>
          </tr>
          <tr>
            <td class="tableHead">Source</td>
            <td class="tableHead" colspan="3">Coverage</td>
          </tr>
{{{subElementsReports}}}
        </tbody>
      </table>
    </center>
    <br />

    <table width="100%" border="0" cellspacing="0" cellpadding="0">
      <tbody>
        <tr>
          <td class="ruler" height="3px"></td>
        </tr>
        <tr>
          <td class="versionInfo">
            Generated by:
            <a href="https://github.com/mrverdant13/coverde"> coverde </a>
          </td>
        </tr>
      </tbody>
    </table>
    <br />
  </body>
</html>
''';

  static final _dirReportTemplate = Template(_dirReportTemplateSource);

  String _generateSubElementReportSegmentContent({
    required Map<String, dynamic> vars,
  }) =>
      _subElementReportSegmentTemplate.renderString(vars);

  String _generateDirReportContent({
    required Map<String, dynamic> vars,
  }) =>
      _dirReportTemplate.renderString(vars);

  String _generateSubElementReportSegment({
    required CovDir covParent,
    required CovElement covSubElement,
    required CovClassSuffixBuilder covClassSuffix,
  }) {
    final relativePath = path.relative(
      covSubElement.source.path,
      from: covParent.source.path,
    );
    final reportRelativePath = () {
      if (covSubElement is CovDir) {
        return path.join(relativePath, 'index.html');
      }
      if (covSubElement is CovFile) return '$relativePath.html';
      throw FallThroughError();
    }();
    final coverage = covSubElement.coverage;

    final vars = <String, dynamic>{
      'reportPath': reportRelativePath,
      'elementPath': relativePath,
      'hitLines': covSubElement.linesHit,
      'foundLines': covSubElement.linesFound,
      'positiveCoverage': covSubElement.coverage > 0,
      'coverage': covSubElement.coverage,
      'covSuffix': covClassSuffix(coverage),
    };

    final segment = _generateSubElementReportSegmentContent(vars: vars);
    return segment;
  }

  /// Generate the coverage report for the given [covDir].
  void generateDirReport({
    required Directory rootReportDir,
    required CovDir covDir,
    required CovClassSuffixBuilder covClassSuffix,
  }) {
    final relativePath = path.canonicalize(
      path.relative(
        covDir.source.path,
        from: projectRootDir.path,
      ),
    );
    final relativePathSegments = path.split(relativePath).where(
          (s) => s != '.',
        );
    final rootRelativePath = path.joinAll(
      List.filled(relativePathSegments.length, '..'),
    );
    final cssRelativePath = path.join(rootRelativePath, 'report_style.css');
    final rootReportRelativePath = path.join(rootRelativePath, 'index.html');
    final dirPath = covDir.source.path;

    final subElementReportSegmentsBuf = StringBuffer();
    for (final subElement in covDir.elements) {
      final subElementReportSegment = _generateSubElementReportSegment(
        covParent: covDir,
        covSubElement: subElement,
        covClassSuffix: covClassSuffix,
      );
      subElementReportSegmentsBuf.writeln(subElementReportSegment);
    }

    final vars = <String, dynamic>{
      'tracefileName': tracefileName,
      'reportRoot': rootReportRelativePath,
      'dirPath': dirPath,
      'hitLines': covDir.linesHit,
      'cssPath': cssRelativePath,
      'foundLines': covDir.linesFound,
      'coverage': covDir.coverage,
      'covSuffix': covClassSuffix(covDir.coverage),
      'date': tracefileModificationDateTime.toString(),
      'subElementsReports': subElementReportSegmentsBuf.toString().trimRight(),
    };

    final reportPath = path.canonicalize(
      path.join(rootReportDir.path, relativePath, 'index.html'),
    );
    final reportFile = File(reportPath);
    if (!reportFile.existsSync()) reportFile.createSync(recursive: true);

    final report = _generateDirReportContent(vars: vars);
    reportFile.writeAsStringSync(report);
  }
}
