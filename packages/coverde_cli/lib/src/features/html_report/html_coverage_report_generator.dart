// cspell:words nbsp,genhtml

import 'package:collection/collection.dart';
import 'package:coverde/src/assets/assets.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:html/dom.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// Writes the genhtml-style coverage report for a [CoverageDirectory] tree.
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
    required CoverageDirectory root,
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

  void _generateDirectory({
    required CoverageDirectory directory,
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
    final suffix = _classSuffix(directory.lineRate, medium: medium, high: high);

    folderReport.head
      ?..querySelector('link')?.attributes['href'] = topLevelCssRelPath
      ..querySelector('.headTitle')?.text = title;
    folderReport.querySelector('.topLevelAnchor')?.attributes['href'] =
        topLevelReportRelPath;
    folderReport.querySelector('.sortAlpha')?.attributes['src'] = path.url.join(
      topLevelDirRelPath,
      sortAlphaPngFilename,
    );
    folderReport.querySelector('.sortNumeric')?.attributes['src'] = path.url
        .join(topLevelDirRelPath, sortNumericPngFilename);
    folderReport.querySelector('.currentDirPath')?.nodes.last.text =
        ' - ${directory.path}';
    folderReport.querySelector('.traceFileName')?.text = traceFileName;
    folderReport.querySelector('.linesHit')?.text = '${directory.linesHit}';
    folderReport.querySelector('.linesFound')?.text = '${directory.linesFound}';
    final covValue = folderReport.querySelector('.covValue');
    covValue?.text = _percentageLabel(directory.lineRate);
    if (suffix != null) {
      covValue?.classes.add('headerCovTableEntry$suffix');
    }
    folderReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final table = folderReport.querySelector('.covTableBody');
    for (final child in directory.directories) {
      final relPath = _relative(child.path, from: directory.path);
      table?.append(
        _folderReportRow(
          relativePath: relPath,
          isDirectory: true,
          lineRate: child.lineRate,
          linesHit: child.linesHit,
          linesFound: child.linesFound,
          medium: medium,
          high: high,
        ),
      );
      _generateDirectory(
        directory: child,
        traceFileName: traceFileName,
        parentReportDirAbsPath: reportDirAbsPath,
        reportDirRelPath: relPath,
        reportRelDepth: reportRelDepth + path.posix.split(relPath).length,
        traceFileModificationDate: traceFileModificationDate,
        medium: medium,
        high: high,
      );
    }
    for (final file in directory.files) {
      final relPath = _relative(file.path, from: directory.path);
      table?.append(
        _folderReportRow(
          relativePath: relPath,
          isDirectory: false,
          lineRate: file.lineRate,
          linesHit: file.linesHit,
          linesFound: file.linesFound,
          medium: medium,
          high: high,
        ),
      );
      _generateFile(
        file: file,
        traceFileName: traceFileName,
        parentReportDirAbsPath: reportDirAbsPath,
        reportDirRelPath: relPath,
        reportRelDepth: reportRelDepth + path.posix.split(relPath).length,
        traceFileModificationDate: traceFileModificationDate,
        medium: medium,
        high: high,
      );
    }

    _writeText(filePath: reportFileAbsPath, contents: folderReport.outerHtml);
  }

  void _generateFile({
    required CoverageFile file,
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
    final currentDirPath = path.posix.dirname(file.path);
    final fileName = path.posix.basename(file.path);
    final suffix = _classSuffix(file.lineRate, medium: medium, high: high);

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
    final covValue = fileReport.querySelector('.covValue');
    covValue?.text = _percentageLabel(file.lineRate);
    if (suffix != null) {
      covValue?.classes.add('headerCovTableEntry$suffix');
    }
    fileReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final src = fileReport.querySelector('.source');
    final sourceLines = () {
      try {
        return File(file.path).readAsLinesSync();
      } on FileSystemException catch (exception, stackTrace) {
        Error.throwWithStackTrace(
          GenerateHtmlCoverageReportFileReadFailure.fromFileSystemException(
            filePath: file.path,
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
      final covLine = file.lines.singleWhereOrNull(
        (line) => line.number == lineNumber,
      );
      final lineHitsText = '${covLine?.hits ?? ''}'.padLeft(11);
      final srcLine = fileReportLine.querySelector('.sourceLine');
      srcLine?.text = '$lineHitsText : $lineContent';
      if (covLine != null) {
        srcLine?.classes.add(covLine.hits > 0 ? 'lineCov' : 'lineNoCov');
      }
      src?.append(fileReportLine);
    }

    _writeText(filePath: reportFileAbsPath, contents: fileReport.outerHtml);
  }

  Element _folderReportRow({
    required String relativePath,
    required bool isDirectory,
    required double? lineRate,
    required int linesHit,
    required int linesFound,
    required double medium,
    required double high,
  }) {
    final sanitizedRelativePath = path.url.joinAll(
      path.posix.split(relativePath),
    );
    final row = _folderReportRowTemplate.clone(true);
    final suffix = _classSuffix(lineRate, medium: medium, high: high);
    final link =
        isDirectory
            ? path.url.join(sanitizedRelativePath, 'index.html')
            : '$sanitizedRelativePath.html';
    row.querySelector('.coverFileAnchor')
      ?..attributes['href'] = link
      ..text = sanitizedRelativePath;
    final covBar = row.querySelector('.barCov');
    if (lineRate == null || lineRate < 1) {
      covBar?.remove();
    } else {
      covBar
        ?..attributes['width'] = '${lineRate.toStringAsFixed(2)}%'
        ..classes.add('barCov$suffix');
    }
    final percentage = row.querySelector('.coverPer');
    percentage?.innerHtml = _percentageHtml(lineRate);
    if (suffix != null) percentage?.classes.add('coverPer$suffix');
    final counts = row.querySelector('.coverNum');
    counts?.innerHtml = '$linesHit&nbsp;/&nbsp;$linesFound';
    if (suffix != null) counts?.classes.add('coverNum$suffix');
    return row;
  }

  String? _classSuffix(
    double? lineRate, {
    required double medium,
    required double high,
  }) {
    if (lineRate == null) return null;
    if (lineRate < medium) return 'Lo';
    if (lineRate < high) return 'Med';
    return 'Hi';
  }

  String _percentageLabel(double? lineRate) {
    if (lineRate == null) return 'n/a';
    return '${lineRate.toStringAsFixed(2)} %';
  }

  String _percentageHtml(double? lineRate) {
    if (lineRate == null) return 'n/a';
    return '${lineRate.toStringAsFixed(2)}&nbsp;%';
  }

  String _relative(String target, {required String from}) {
    if (from.isEmpty) return target;
    return path.posix.relative(target, from: from);
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
