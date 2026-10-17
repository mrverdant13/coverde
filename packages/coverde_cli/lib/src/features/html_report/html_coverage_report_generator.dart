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

  void _generateElement({
    required CovElement element,
    required String traceFileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required _ReportLayout layout,
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
        layout: layout,
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
      layout: layout,
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
      final relPath = layout.relative(
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
    required CovFile file,
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

    final reportFileAbsPath = layout.inside(
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

final class _ReportLayout {
  _ReportLayout({required this.reportRootAbsPath});

  final String reportRootAbsPath;
  String absoluteNamespace = 'absolute';
  final Map<String, String> driveNamespaces = <String, String>{};

  static final _driveLetter = RegExp('^([A-Za-z]):');

  void collect(CovDir root) {
    final used = <String>{};
    final drives = <String>{};
    void visit(CovElement element) {
      final normalized = CovFile.normalizeSourcePath(element.source.path);
      final drive = _letter(normalized);
      if (drive != null) {
        drives.add(drive);
      } else if (!path.posix.isAbsolute(normalized)) {
        final parts = path.posix.split(normalized);
        if (parts.isNotEmpty && parts.first != '.' && parts.first != '..') {
          used.add(parts.first);
        }
      }
      if (element is CovDir) {
        element.elements.forEach(visit);
      }
    }

    visit(root);
    absoluteNamespace = _freeName(used, 'absolute');
    used.add(absoluteNamespace);
    for (final drive in drives) {
      final namespace = _freeName(used, 'drive-$drive');
      driveNamespaces[drive] = namespace;
      used.add(namespace);
    }
  }

  String relative(String target, {required String from}) {
    final to = CovFile.normalizeSourcePath(target);
    final base = CovFile.normalizeSourcePath(from);
    if (base.isEmpty || base == '.') {
      if (path.posix.isAbsolute(to)) {
        final stripped = path.posix.relative(to, from: '/');
        if (stripped == '.') return absoluteNamespace;
        return path.posix.join(absoluteNamespace, stripped);
      }
      final drive = _letter(to);
      if (drive != null) {
        final namespace = driveNamespaces[drive] ?? 'drive-$drive';
        final rest = to
            .substring(drive.length + 1)
            .replaceFirst(RegExp('^/+'), '');
        if (rest.isEmpty) return namespace;
        return path.posix.join(namespace, rest);
      }
      return to == '.' ? '' : to;
    }
    return path.posix.relative(to, from: base);
  }

  String inside(String parentAbsPath, String relativePath) {
    final destination = path.normalize(path.join(parentAbsPath, relativePath));
    final root = path.normalize(reportRootAbsPath);
    final parts =
        relativePath.isEmpty
            ? const <String>[]
            : path.posix.split(relativePath);
    final escapes =
        path.posix.isAbsolute(relativePath) ||
        _letter(CovFile.normalizeSourcePath(relativePath)) != null ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
        (!path.equals(destination, root) && !path.isWithin(root, destination));
    if (escapes) {
      throw GenerateHtmlCoverageReportOutsideDirectoryFailure(
        sourcePath: relativePath,
      );
    }
    return destination;
  }

  static String? _letter(String posixPath) {
    return _driveLetter.firstMatch(posixPath)?.group(1)?.toLowerCase();
  }

  static String _freeName(Set<String> used, String base) {
    if (!used.contains(base)) return base;
    var suffix = 2;
    while (used.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }
}
