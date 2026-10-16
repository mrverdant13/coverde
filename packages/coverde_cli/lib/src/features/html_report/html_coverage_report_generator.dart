// cspell:words nbsp,genhtml

import 'package:collection/collection.dart';
import 'package:coverde/src/assets/assets.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:html/dom.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// Writes the genhtml-style coverage report for a [CovDir] tree.
///
/// The pages, stylesheet, and sort icons match the report previously written
/// by [CovElement].
class HtmlCoverageReportGenerator {
  /// Creates a generator.
  const HtmlCoverageReportGenerator();

  static final _folderReportTemplate = Document.html(
    String.fromCharCodes(folderReportTemplateHtmlBytes),
  );

  static final _folderReportRowTemplate = Element.html(
    String.fromCharCodes(folderReportRowTemplateHtmlBytes),
  );

  static final _fileReportTemplate = Document.html(
    String.fromCharCodes(fileReportTemplateHtmlBytes),
  );

  static final _fileReportLineTemplate = Element.html(
    String.fromCharCodes(fileReportLineTemplateHtmlBytes),
  );

  /// Writes the report for [root] under [parentReportDirAbsPath].
  ///
  /// Throws a [GenerateHtmlCoverageReportFailure] if a file operation fails.
  void generate({
    required CovDir root,
    required String traceFileName,
    required String parentReportDirAbsPath,
    required DateTime traceFileModificationDate,
    required double medium,
    required double high,
  }) {
    _generateDirectory(
      directory: root,
      traceFileName: traceFileName,
      parentReportDirAbsPath: parentReportDirAbsPath,
      reportDirRelPath: '',
      reportRelDepth: 0,
      traceFileModificationDate: traceFileModificationDate,
      medium: medium,
      high: high,
    );
    _copyAsset(
      filePath: path.join(parentReportDirAbsPath, reportStyleCssFilename),
      bytes: reportStyleCssBytes,
    );
    _copyAsset(
      filePath: path.join(parentReportDirAbsPath, sortAlphaPngFilename),
      bytes: sortAlphaPngBytes,
    );
    _copyAsset(
      filePath: path.join(parentReportDirAbsPath, sortNumericPngFilename),
      bytes: sortNumericPngBytes,
    );
  }

  void _generateElement({
    required CovElement element,
    required String traceFileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required DateTime traceFileModificationDate,
    required double medium,
    required double high,
  }) {
    if (element is CovFile) {
      _generateFile(
        file: element,
        traceFileName: traceFileName,
        parentReportDirAbsPath: parentReportDirAbsPath,
        reportDirRelPath: reportDirRelPath,
        reportRelDepth: reportRelDepth,
        traceFileModificationDate: traceFileModificationDate,
        medium: medium,
        high: high,
      );
      return;
    }
    _generateDirectory(
      directory: element as CovDir,
      traceFileName: traceFileName,
      parentReportDirAbsPath: parentReportDirAbsPath,
      reportDirRelPath: reportDirRelPath,
      reportRelDepth: reportRelDepth,
      traceFileModificationDate: traceFileModificationDate,
      medium: medium,
      high: high,
    );
  }

  void _generateDirectory({
    required CovDir directory,
    required String traceFileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required DateTime traceFileModificationDate,
    required double medium,
    required double high,
  }) {
    final folderReport = _folderReportTemplate.clone(true);

    final topLevelDirRelPath = path.url.joinAll(
      List.filled(reportRelDepth, '..'),
    );
    final topLevelReportRelPath = path.url.join(
      topLevelDirRelPath,
      'index.html',
    );
    final topLevelCssRelPath = path.url.join(
      topLevelDirRelPath,
      reportStyleCssFilename,
    );

    final reportDirAbsPath = path.join(
      parentReportDirAbsPath,
      reportDirRelPath,
    );
    final reportFileAbsPath = path.join(reportDirAbsPath, 'index.html');

    final title = 'Coverage Report - $traceFileName';
    final sortAlphaIconPath = path.url.join(
      topLevelDirRelPath,
      sortAlphaPngFilename,
    );
    final sortNumericIconPath = path.url.join(
      topLevelDirRelPath,
      sortNumericPngFilename,
    );
    final suffix = _classSuffix(directory, medium: medium, high: high);

    folderReport.head
      ?..querySelector('link')?.attributes['href'] = topLevelCssRelPath
      ..querySelector('.headTitle')?.text = title;

    folderReport.querySelector('.topLevelAnchor')?.attributes['href'] =
        topLevelReportRelPath;
    folderReport.querySelector('.sortAlpha')?.attributes['src'] =
        sortAlphaIconPath;
    folderReport.querySelector('.sortNumeric')?.attributes['src'] =
        sortNumericIconPath;
    folderReport.querySelector('.currentDirPath')?.nodes.last.text =
        ' - ${path.url.joinAll(path.split(directory.source.path))}';
    folderReport.querySelector('.traceFileName')?.text = traceFileName;
    folderReport.querySelector('.linesHit')?.text = '${directory.linesHit}';
    folderReport.querySelector('.linesFound')?.text = '${directory.linesFound}';
    folderReport.querySelector('.covValue')
      ?..text = '${directory.coverageString} %'
      ..classes.add('headerCovTableEntry$suffix');

    folderReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final table = folderReport.querySelector('.covTableBody');
    for (final element in directory.elements) {
      final relPath = path.relative(
        element.source.path,
        from: directory.source.path,
      );
      table?.append(
        _folderReportRow(
          element,
          relativePath: relPath,
          medium: medium,
          high: high,
        ),
      );
      _generateElement(
        element: element,
        traceFileName: traceFileName,
        parentReportDirAbsPath: reportDirAbsPath,
        reportDirRelPath: relPath,
        reportRelDepth: reportRelDepth + path.split(relPath).length,
        traceFileModificationDate: traceFileModificationDate,
        medium: medium,
        high: high,
      );
    }

    _writeText(filePath: reportFileAbsPath, contents: folderReport.outerHtml);
  }

  void _generateFile({
    required CovFile file,
    required String traceFileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required DateTime traceFileModificationDate,
    required double medium,
    required double high,
  }) {
    final fileReport = _fileReportTemplate.clone(true);

    final topLevelDirRelPath =
        (reportRelDepth > 1)
            ? path.url.joinAll(List.filled(reportRelDepth - 1, '..'))
            : '.';
    final topLevelReportRelPath = path.url.join(
      topLevelDirRelPath,
      'index.html',
    );
    final topLevelCssRelPath = path.url.join(
      topLevelDirRelPath,
      reportStyleCssFilename,
    );

    final reportFileAbsPath = path.join(
      parentReportDirAbsPath,
      '$reportDirRelPath.html',
    );

    final title = 'Coverage Report - $traceFileName';
    final currentDirPath = path.url.joinAll(
      path.split(file.source.parent.path),
    );
    final fileName = path.basename(file.source.path);
    final suffix = _classSuffix(file, medium: medium, high: high);

    fileReport.head
      ?..querySelector('link')?.attributes['href'] = topLevelCssRelPath
      ..querySelector('.headTitle')?.text = title;

    fileReport.querySelector('.topLevelAnchor')?.attributes['href'] =
        topLevelReportRelPath;
    fileReport.querySelector('.currentDirPath')?.text = currentDirPath;
    fileReport.querySelector('.currentFileName')?.nodes.last.text =
        ' - $fileName';
    fileReport.querySelector('.traceFileName')?.text = traceFileName;
    fileReport.querySelector('.linesHit')?.text = '${file.linesHit}';
    fileReport.querySelector('.linesFound')?.text = '${file.linesFound}';
    fileReport.querySelector('.covValue')
      ?..text = '${file.coverageString} %'
      ..classes.add('headerCovTableEntry$suffix');

    fileReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final src = fileReport.querySelector('.source');
    final sourceLines = () {
      try {
        return file.source.readAsLinesSync();
      } on FileSystemException catch (exception, stackTrace) {
        Error.throwWithStackTrace(
          GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: file.source.path,
            exception: exception,
          ),
          stackTrace,
        );
      }
    }();
    for (final sourceLine in sourceLines.asMap().entries) {
      final lineNumber = sourceLine.key + 1;
      final lineContent = sourceLine.value;
      final fileReportLine = _fileReportLineTemplate.clone(true);
      fileReportLine.querySelector('.lineNum')?.text = '$lineNumber '.padLeft(
        9,
      );
      final covLine = file.covLines.singleWhereOrNull(
        (line) => line.lineNumber == lineNumber,
      );
      final lineHitsText = '${covLine?.hitsNumber ?? ''}'.padLeft(11);
      final srcLine = fileReportLine.querySelector('.sourceLine');
      srcLine?.text = '$lineHitsText : $lineContent';
      if (covLine != null) {
        srcLine?.classes.add(covLine.hasBeenHit ? 'lineCov' : 'lineNoCov');
      }
      src?.append(fileReportLine);
    }

    _writeText(filePath: reportFileAbsPath, contents: fileReport.outerHtml);
  }

  Element _folderReportRow(
    CovElement element, {
    required String relativePath,
    required double medium,
    required double high,
  }) {
    final sanitizedRelativePath = path.url.joinAll(path.split(relativePath));
    final row = _folderReportRowTemplate.clone(true);
    final suffix = _classSuffix(element, medium: medium, high: high);
    final link =
        element.source is Directory
            ? path.url.join(sanitizedRelativePath, 'index.html')
            : '$sanitizedRelativePath.html';
    row.querySelector('.coverFileAnchor')
      ?..attributes['href'] = link
      ..text = sanitizedRelativePath;
    final covBar = row.querySelector('.barCov');
    if (element.coverage < 1) {
      covBar?.remove();
    } else {
      covBar
        ?..attributes['width'] = '${element.coverageString}%'
        ..classes.add('barCov$suffix');
    }
    row.querySelector('.coverPer')
      ?..classes.add('coverPer$suffix')
      ..innerHtml = '${element.coverageString}&nbsp;%';
    row.querySelector('.coverNum')
      ?..classes.add('coverNum$suffix')
      ..innerHtml = '${element.linesHit}&nbsp;/&nbsp;${element.linesFound}';
    return row;
  }

  String _classSuffix(
    CovComputable element, {
    required double medium,
    required double high,
  }) {
    if (element.coverage < medium) {
      return 'Lo';
    } else if (element.coverage < high) {
      return 'Med';
    } else {
      return 'Hi';
    }
  }

  void _copyAsset({required String filePath, required List<int> bytes}) {
    final file = File(filePath);
    try {
      file.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        GenerateHtmlCoverageReportFileCreateFailure.fromFileSystemException(
          filePath: filePath,
          exception: exception,
        ),
        stackTrace,
      );
    }
    try {
      file.writeAsBytesSync(bytes);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        GenerateHtmlCoverageReportFileWriteFailure.fromFileSystemException(
          filePath: filePath,
          exception: exception,
        ),
        stackTrace,
      );
    }
  }

  void _writeText({required String filePath, required String contents}) {
    final file = File(filePath);
    try {
      file.createSync(recursive: true);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        GenerateHtmlCoverageReportFileCreateFailure.fromFileSystemException(
          filePath: filePath,
          exception: exception,
        ),
        stackTrace,
      );
    }
    try {
      file.writeAsStringSync(contents);
    } on FileSystemException catch (exception, stackTrace) {
      Error.throwWithStackTrace(
        GenerateHtmlCoverageReportFileWriteFailure.fromFileSystemException(
          filePath: filePath,
          exception: exception,
        ),
        stackTrace,
      );
    }
  }
}
