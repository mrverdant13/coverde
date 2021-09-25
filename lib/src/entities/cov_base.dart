import 'dart:io';
import 'package:coverde/src/common/assets.dart';
import 'package:html/dom.dart';
import 'package:path/path.dart' as p;

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
}

/// # Coverage Filesystem Element
///
/// The definition of the minimum conditions that should be met by a covered
/// filesystem instance.
abstract class CovElement extends CovComputable {
  /// The tested filesystem element.
  FileSystemEntity get source;

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

  /// Folder report row HTML template file.
  static final _folderReportRowTemplateFile = File(
    p.join(
      assetsPath,
      'folder-report-row-template.html',
    ),
  );

  /// Folder report row HTML element template.
  static final _folderReportRowTemplate = Element.html(
    _folderReportRowTemplateFile.readAsStringSync(),
  );

  /// Get the coverage data to a HTML report row.
  Element getFolderReportRow({
    required String relativePath,
  }) {
    final row = _folderReportRowTemplate.clone(true);
    final link = source is Directory
        ? p.join(relativePath, 'index.html')
        : '$relativePath.html';
    row.querySelector('.coverFileAnchor')
      ?..attributes['href'] = link
      ..text = relativePath;
    row.querySelector('.barCov')
      ?..attributes['width'] = '$coverageString%'
      ..classes.add('barCovHi');
    row.querySelector('.coverPer')
      ?..classes.add('coverPerHi')
      ..innerHtml = '$coverageString&nbsp;%';
    row.querySelector('.coverNum')
      ?..classes.add('coverNumHi')
      ..innerHtml = '$linesHit&nbsp;/&nbsp;$linesFound';
    return row;
  }
}
