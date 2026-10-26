// cspell:words nbsp,genhtml

import 'package:collection/collection.dart';
import 'package:coverde/src/assets/assets.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/coverage.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:coverde/src/utils/report_paths.dart';
import 'package:html/dom.dart';
import 'package:meta/meta.dart';
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
    final layout = _ReportLayout(reportRootAbsPath: parentReportDirAbsPath)
      ..collect(root);
    _generateDirectory(
      directory: root,
      traceFileName: traceFileName,
      parentReportDirAbsPath: parentReportDirAbsPath,
      reportDirRelPath: '',
      reportRelDepth: 0,
      layout: layout,
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
    required _ReportLayout layout,
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

    final reportDirAbsPath = layout.inside(
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
    final rate = coverageRate(
      hit: directory.linesHit,
      found: directory.linesFound,
    );

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
        ' - ${path.url.joinAll(path.split(directory.path))}';
    folderReport.querySelector('.traceFileName')?.text = traceFileName;
    folderReport.querySelector('.linesHit')?.text = '${directory.linesHit}';
    folderReport.querySelector('.linesFound')?.text = '${directory.linesFound}';
    _writeCoverageValue(
      folderReport.querySelector('.covValue'),
      rate,
      medium: medium,
      high: high,
    );

    folderReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final table = folderReport.querySelector('.covTableBody');
    for (final child in directory.directories) {
      final relPath = layout.relative(child.path, from: directory.path);
      table?.append(
        _folderReportRow(
          relativePath: relPath,
          isDirectory: true,
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
        layout: layout,
        traceFileModificationDate: traceFileModificationDate,
        medium: medium,
        high: high,
      );
    }
    for (final file in directory.files) {
      final relPath = layout.relative(file.path, from: directory.path);
      table?.append(
        _folderReportRow(
          relativePath: relPath,
          isDirectory: false,
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
        layout: layout,
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
    required _ReportLayout layout,
    required DateTime traceFileModificationDate,
    required double medium,
    required double high,
  }) {
    final fileReport = _fileReportTemplate.clone(true);

    final topLevelDirRelPath = (reportRelDepth > 1)
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

    final reportFileAbsPath = layout.inside(
      parentReportDirAbsPath,
      '$reportDirRelPath.html',
    );

    final title = 'Coverage Report - $traceFileName';
    final currentDirPath = path.url.joinAll(
      path.split(path.dirname(coveragePathSlashForm(file.path))),
    );
    final fileName = path.posix.basename(coveragePathSlashForm(file.path));
    final rate = coverageRate(hit: file.linesHit, found: file.linesFound);

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
    _writeCoverageValue(
      fileReport.querySelector('.covValue'),
      rate,
      medium: medium,
      high: high,
    );

    fileReport.querySelector('.lastTraceFileModificationDate')?.text =
        traceFileModificationDate.toString();

    final src = fileReport.querySelector('.source');
    final sourceLines = () {
      if (!hostCanResolveCoveragePath(
        file.path,
        windowsHost: Platform.isWindows,
      )) {
        throw GenerateHtmlCoverageReportUnresolvedCoveragePathFailure(
          sourcePath: file.path,
        );
      }
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
        srcLine?.classes.add(covLine.hasBeenHit ? 'lineCov' : 'lineNoCov');
      }
      src?.append(fileReportLine);
    }

    _writeText(filePath: reportFileAbsPath, contents: fileReport.outerHtml);
  }

  Element _folderReportRow({
    required String relativePath,
    required bool isDirectory,
    required int linesHit,
    required int linesFound,
    required double medium,
    required double high,
  }) {
    final sanitizedRelativePath = path.url.joinAll(path.split(relativePath));
    final row = _folderReportRowTemplate.clone(true);
    final rate = coverageRate(hit: linesHit, found: linesFound);
    final link = isDirectory
        ? path.url.join(sanitizedRelativePath, 'index.html')
        : '$sanitizedRelativePath.html';
    row.querySelector('.coverFileAnchor')
      ?..attributes['href'] = link
      ..text = sanitizedRelativePath;
    final covBar = row.querySelector('.barCov');
    if (rate == null) {
      covBar?.remove();
      row.querySelector('.coverPer')?.text = 'n/a';
    } else {
      final suffix = _classSuffix(rate, medium: medium, high: high);
      if (rate < 1) {
        covBar?.remove();
      } else {
        covBar
          ?..attributes['width'] = '${_coverageString(rate)}%'
          ..classes.add('barCov$suffix');
      }
      row.querySelector('.coverPer')
        ?..classes.add('coverPer$suffix')
        ..innerHtml = '${_coverageString(rate)}&nbsp;%';
      row.querySelector('.coverNum')?.classes.add('coverNum$suffix');
    }
    row.querySelector('.coverNum')?.innerHtml =
        '$linesHit&nbsp;/&nbsp;$linesFound';
    return row;
  }

  void _writeCoverageValue(
    Element? element,
    double? rate, {
    required double medium,
    required double high,
  }) {
    if (rate == null) {
      element?.text = 'n/a';
      return;
    }
    final suffix = _classSuffix(rate, medium: medium, high: high);
    element
      ?..text = '${_coverageString(rate)} %'
      ..classes.add('headerCovTableEntry$suffix');
  }

  String _classSuffix(
    double rate, {
    required double medium,
    required double high,
  }) {
    if (rate < medium) {
      return 'Lo';
    } else if (rate < high) {
      return 'Med';
    } else {
      return 'Hi';
    }
  }

  String _coverageString(double rate) => rate.toStringAsFixed(2);

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

/// Report-relative path for [sourcePath] among [sourcePaths].
@visibleForTesting
String coverageReportRelativePath({
  required Iterable<String> sourcePaths,
  required String sourcePath,
  String from = '',
}) {
  final layout = _ReportLayout(reportRootAbsPath: '.')
    ..collectPaths(sourcePaths);
  return layout.relative(sourcePath, from: from);
}

final class _ReportLayout {
  _ReportLayout({required this.reportRootAbsPath});

  final String reportRootAbsPath;
  final ReportPaths _paths = ReportPaths();

  void collect(CoverageDirectory root) {
    _paths.collectTree(root);
  }

  void collectPaths(Iterable<String> sourcePaths) {
    _paths.collectPaths(sourcePaths);
  }

  String relative(String target, {required String from}) {
    return _paths.relative(target, from: from);
  }

  String inside(String parentAbsPath, String relativePath) {
    final destination = path.normalize(path.join(parentAbsPath, relativePath));
    final root = path.normalize(reportRootAbsPath);
    final parts = relativePath.isEmpty
        ? const <String>[]
        : path.posix.split(relativePath);
    final escapes =
        path.posix.isAbsolute(relativePath) ||
        ReportPaths.driveLetter(
              coveragePathSlashForm(normalizeCoveragePath(relativePath)),
            ) !=
            null ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
        (!path.equals(destination, root) && !path.isWithin(root, destination));
    if (escapes) {
      throw GenerateHtmlCoverageReportOutsideDirectoryFailure(
        sourcePath: relativePath,
      );
    }
    return destination;
  }
}
