import 'package:coverde/src/assets/folder_report_row_template.html.asset.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:html/dom.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// # Computable Coverage Entity
///
/// The definition of base values that an instance should implement when it
/// includes coverage data regarding tested lines and total testable lines.
abstract class CovComputable {
  /// The number of tested lines in this instance.
  int get linesHit;

  /// The number of found lines in this instance.
  int get linesFound;

  /// The percentage of code coverage for this instance.
  ///
  /// From **0.00** to **100.00**.
  double get coverage => (linesHit * 100) / linesFound;

  /// The string representation of the [coverage] value.
  ///
  /// From **0.00** to **100.00**.
  String get coverageString => coverage.toStringAsFixed(2);

  /// The string representation of the [coverage] value, hte [linesHit] and the
  /// [linesFound].
  String get coverageDataString => '$coverageString% - $linesHit/$linesFound';
}

/// # Coverage Filesystem Element
///
/// The definition of the minimum conditions that should be met by a covered
/// filesystem instance.
abstract class CovElement extends CovComputable {
  /// The tested filesystem element.
  FileSystemEntity get source;

  /// The string representation of the [coverage] value, hte [linesHit] and the
  /// [linesFound].
  @override
  String get coverageDataString {
    final color = coverage < 100 ? lightRed : lightGreen;
    return '${source.path} ${color.wrap('(${super.coverageDataString})')}';
  }

  /// Generate HTML coverage report for this element.
  void generateSubReport({
    required String tracefileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required DateTime tracefileModificationDate,
    required double medium,
    required double high,
  });

  /// Folder report row HTML element template.
  static final _folderReportRowTemplate = Element.html(
    String.fromCharCodes(folderReportRowTemplateHtmlBytes),
  );

  /// Obtain the HTML class suffix for coverage element.
  @protected
  String getClassSuffix({
    required double medium,
    required double high,
  }) {
    if (coverage < medium) {
      return 'Lo';
    } else if (coverage < high) {
      return 'Med';
    } else {
      return 'Hi';
    }
  }

  /// Get the coverage data to a HTML report row.
  Element getFolderReportRow({
    required String relativePath,
    required double medium,
    required double high,
  }) {
    final row = _folderReportRowTemplate.clone(true);
    final suffix = getClassSuffix(medium: medium, high: high);
    final link = source is Directory
        ? path.join(relativePath, 'index.html')
        : '$relativePath.html';
    row.querySelector('.coverFileAnchor')
      ?..attributes['href'] = link
      ..text = relativePath;
    {
      final covBar = row.querySelector('.barCov');
      if (coverage < 1) {
        covBar?.remove();
      } else {
        covBar
          ?..attributes['width'] = '$coverageString%'
          ..classes.add('barCov$suffix');
      }
    }
    row.querySelector('.coverPer')
      ?..classes.add('coverPer$suffix')
      ..innerHtml = '$coverageString&nbsp;%';
    row.querySelector('.coverNum')
      ?..classes.add('coverNum$suffix')
      ..innerHtml = '$linesHit&nbsp;/&nbsp;$linesFound';
    return row;
  }
}
