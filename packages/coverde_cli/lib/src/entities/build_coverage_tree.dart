import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/utils/path.dart';

final _uncRoot = RegExp('^//([^/]+)/([^/]+)');
final _driveRoot = RegExp('^[A-Za-z]:/');

/// Builds a directory tree whose root path is the shared parent prefix.
///
/// The root path is empty when [files] do not share a parent directory.
/// `\` and `/` are both separators. A drive or UNC root stays one root.
/// A chain of directories that contains a single child and no files collapses
/// into one node.
CoverageDirectory buildCoverageTree(Iterable<CoverageFile> files) {
  final list = files.toList();
  return _subtree(const <String>[], list, [
    for (final file in list) _parentSegments(file.path),
  ]);
}

CoverageDirectory _subtree(
  List<String> base,
  List<CoverageFile> files,
  List<List<String>> parents,
) {
  final prefix = [...base];
  var index = base.length;
  if (parents.isNotEmpty) {
    final fewest = parents
        .map((parent) => parent.length)
        .reduce((left, right) => left < right ? left : right);
    while (index < fewest && _sameSegment(parents, index)) {
      prefix.add(parents.first[index]);
      index++;
    }
  }
  final childFiles = <String, List<CoverageFile>>{};
  final childParents = <String, List<List<String>>>{};
  final childOrder = <String>[];
  final filesHere = <CoverageFile>[];
  for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
    final parent = parents[fileIndex];
    if (parent.length == index) {
      filesHere.add(files[fileIndex]);
      continue;
    }
    final segment = parent[index];
    final children = childFiles[segment];
    if (children == null) {
      childFiles[segment] = [files[fileIndex]];
      childParents[segment] = [parent];
      childOrder.add(segment);
    } else {
      children.add(files[fileIndex]);
      childParents[segment]!.add(parent);
    }
  }
  return CoverageDirectory(
    path: _directoryPath(prefix),
    directories: [
      for (final segment in childOrder)
        _subtree(
          [...prefix, segment],
          childFiles[segment]!,
          childParents[segment]!,
        ),
    ],
    files: filesHere,
  );
}

bool _sameSegment(List<List<String>> parents, int index) {
  final segment = parents.first[index];
  for (final parent in parents) {
    if (parent[index] != segment) return false;
  }
  return true;
}

String _directoryPath(List<String> segments) {
  if (segments.isEmpty) return '';
  if (segments.first == '/') {
    if (segments.length == 1) return '/';
    return '/${segments.skip(1).join('/')}';
  }
  if (segments.first.startsWith('//')) {
    if (segments.length == 1) return segments.first;
    return '${segments.first}/${segments.skip(1).join('/')}';
  }
  return segments.join('/');
}

List<String> _parentSegments(String filePath) {
  final segments = _segments(coveragePathSlashForm(filePath));
  if (segments.length <= 1) return const [];
  return segments.sublist(0, segments.length - 1);
}

List<String> _segments(String slashPath) {
  final unc = _uncRoot.firstMatch(slashPath);
  if (unc != null) {
    final root = '//${unc.group(1)}/${unc.group(2)}';
    return [root, ..._tail(slashPath.substring(root.length))];
  }
  if (_driveRoot.hasMatch(slashPath)) {
    return [slashPath.substring(0, 2), ..._tail(slashPath.substring(2))];
  }
  if (slashPath.startsWith('/')) {
    return ['/', ..._tail(slashPath.substring(1))];
  }
  return _tail(slashPath);
}

List<String> _tail(String raw) {
  return [
    for (final part in raw.split('/'))
      if (part.isNotEmpty) part,
  ];
}
