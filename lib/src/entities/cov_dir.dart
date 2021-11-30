import 'package:collection/collection.dart';
import 'package:coverde/src/assets/folder_report_template.html.asset.dart';
import 'package:coverde/src/assets/report_style.css.asset.dart';
import 'package:coverde/src/assets/sort_alpha.png.asset.dart';
import 'package:coverde/src/assets/sort_numeric.png.asset.dart';
import 'package:coverde/src/entities/cov_base.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:html/dom.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template cov_dir}
/// # Covered Directory
///
/// A [CovElement] that holds coverage data about a [source] directory.
///
/// The data includes coverage [elements] that encapsulates coverage data about
/// all filesystem entities within the [source] folder.
/// {@endtemplate}
@immutable
class CovDir extends CovElement {
  /// Create a [CovDir] instance.
  ///
  /// {@macro cov_dir}
  @visibleForTesting
  CovDir({
    required this.source,
    required Iterable<CovElement> elements,
  }) : _elements = elements;

  /// Create a coverage data tree structure that replicates the [source]
  /// organization in the filesystem.
  factory CovDir.tree({
    required Iterable<CovFile> covFiles,
  }) =>
      CovDir.subtree(
        baseDirPath: null,
        coveredFiles: covFiles,
      );

  /// Create a coverage data tree structure that replicates filesystem tree
  /// organization with the given [coveredFiles] and [baseDirPath].
  @visibleForTesting
  factory CovDir.subtree({
    required String? baseDirPath,
    required Iterable<CovFile> coveredFiles,
  }) {
    // Filter files directly or indirectly within this directory.
    final covFiles = baseDirPath == null
        ? coveredFiles
        : coveredFiles.where(
            (covFile) => path.isWithin(
              baseDirPath,
              covFile.source.path,
            ),
          );

    // If no covered files within this folder, return the covered directory.
    if (covFiles.isEmpty) {
      return CovDir(
        source: Directory(baseDirPath ?? ''),
        elements: const [],
      );
    }

    // Folders directly or indirectly within this directory.
    final dirPaths =
        covFiles.map((covFile) => covFile.source.parent.path).toSet();

    // Get folders segments.
    final dirsSegments = dirPaths.map(path.split).toList();

    // Pick path with fewest number of segments.
    final fewestSegments = minBy<Iterable<String>, int>(
      dirsSegments,
      (dirSegments) => dirSegments.length,
    )!;

    final commonSegments =
        baseDirPath == null ? <String>[] : path.split(baseDirPath);

    final Iterable<String> nextSegments;
    {
      var segmentIdx = commonSegments.length;

      bool shortestPathChecked() => segmentIdx >= fewestSegments.length;

      Iterable<String> nextSegmentsGroup() => dirsSegments
          .where((s) => s.length > segmentIdx)
          .map((s) => s[segmentIdx])
          .toSet();

      while (!shortestPathChecked() && nextSegmentsGroup().length <= 1) {
        commonSegments.addAll(nextSegmentsGroup());
        segmentIdx++;
      }

      nextSegments = nextSegmentsGroup();
    }

    // Build actual base path.
    final actualBasePath = commonSegments.reduce(path.join);

    // Build nested folders data from next segments.
    final allDirs = nextSegments.map(
      (nextSegment) => CovDir.subtree(
        baseDirPath: path.join(actualBasePath, nextSegment),
        coveredFiles: covFiles,
      ),
    );
    final validDirs = allDirs.where((dir) => dir.linesFound > 0);

    final files = covFiles.where(
      (covFile) => path.equals(covFile.source.parent.path, actualBasePath),
    );

    return CovDir(
      source: Directory(actualBasePath),
      elements: [
        ...validDirs,
        ...files,
      ],
    );
  }

  @override
  final Directory source;

  final Iterable<CovElement> _elements;

  /// The organized coverage data about the filesystem entities within the
  /// [source] folder.
  late final UnmodifiableListView<CovElement> elements =
      UnmodifiableListView(_elements);

  @override
  late final linesFound = _elements.map((e) => e.linesFound).sum;

  @override
  late final linesHit = _elements.map((e) => e.linesHit).sum;

  static const _equality = IterableEquality<CovElement>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CovDir &&
        path.equals(other.source.path, source.path) &&
        _equality.equals(other._elements, _elements);
  }

  @override
  int get hashCode =>
      path.canonicalize(source.path).hashCode ^ _equality.hash(_elements);

  @override
  String toString() {
    final buf = StringBuffer(
      'Node: $coverageDataString',
    );
    elements.map(
      (e) {
        if (e is CovFile) {
          return '\n├─ SF: ${e.coverageDataString}';
        } else if (e is CovDir) {
          return '\n├─ ${e.toString().replaceAll('\n', '\n│  ')}';
        }
      },
    ).forEach(buf.write);
    buf.writeln();
    return buf.toString();
  }

  /// Folder report HTML element template.
  @visibleForTesting
  static final folderReportTemplate = Document.html(
    String.fromCharCodes(folderReportTemplateHtmlBytes),
  );

  /// Generate HTML report for this directory and its children.
  void generateReport({
    required String tracefileName,
    required String parentReportDirAbsPath,
    required DateTime tracefileModificationDate,
    required double medium,
    required double high,
  }) =>
      generateSubReport(
        tracefileName: tracefileName,
        parentReportDirAbsPath: parentReportDirAbsPath,
        reportDirRelPath: '',
        reportRelDepth: 0,
        tracefileModificationDate: tracefileModificationDate,
        medium: medium,
        high: high,
      );

  @override
  void generateSubReport({
    required String tracefileName,
    required String parentReportDirAbsPath,
    required String reportDirRelPath,
    required int reportRelDepth,
    required DateTime tracefileModificationDate,
    required double medium,
    required double high,
  }) {
    final folderReport = folderReportTemplate.clone(true);

    final topLevelDirRelPath =
        List.filled(reportRelDepth, '..').fold('', path.join);
    final topLevelReportRelPath = path.join(topLevelDirRelPath, 'index.html');
    final topLevelCssRelPath = path.join(
      topLevelDirRelPath,
      reportStyleCssFilename,
    );

    final reportDirAbsPath = path.join(
      parentReportDirAbsPath,
      reportDirRelPath,
    );
    final reportFileAbsPath = path.join(reportDirAbsPath, 'index.html');

    final title = 'Coverage Report - $tracefileName';
    final sortAlphaIconPath = path.join(
      topLevelDirRelPath,
      sortAlphaPngFilename,
    );
    final sortNumericIconPath = path.join(
      topLevelDirRelPath,
      sortNumericPngFilename,
    );
    final suffix = getClassSuffix(medium: medium, high: high);

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
        ' - ${source.path}';
    folderReport.querySelector('.tracefileName')?.text = tracefileName;
    folderReport.querySelector('.linesHit')?.text = '$linesHit';
    folderReport.querySelector('.linesFound')?.text = '$linesFound';
    folderReport.querySelector('.covValue')
      ?..text = '$coverageString %'
      ..classes.add('headerCovTableEntry$suffix');

    folderReport.querySelector('.lastTracefileModificationDate')?.text =
        tracefileModificationDate.toString();

    {
      final table = folderReport.querySelector('.covTableBody');

      for (final element in _elements) {
        final relPath = path.relative(element.source.path, from: source.path);
        final row = element.getFolderReportRow(
          relativePath: relPath,
          medium: medium,
          high: high,
        );
        table?.append(row);
        element.generateSubReport(
          tracefileName: tracefileName,
          parentReportDirAbsPath: reportDirAbsPath,
          reportDirRelPath: relPath,
          reportRelDepth: reportRelDepth + path.split(relPath).length,
          tracefileModificationDate: tracefileModificationDate,
          medium: medium,
          high: high,
        );
      }
    }

    File(reportFileAbsPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(folderReport.outerHtml);
  }
}
