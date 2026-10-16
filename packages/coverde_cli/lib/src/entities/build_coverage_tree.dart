import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:path/path.dart' as path;

/// Builds a directory tree whose root path is the shared parent prefix.
///
/// The root path is empty when [files] do not share a parent directory.
/// A chain of directories that contains a single child and no files collapses
/// into one node.
CoverageDirectory buildCoverageTree(Iterable<CoverageFile> files) {
  return _subtree(const <String>[], files.toList());
}

CoverageDirectory _subtree(List<String> base, List<CoverageFile> files) {
  final parents = [for (final file in files) _parentSegments(file.path)];
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
      childOrder.add(segment);
    } else {
      children.add(files[fileIndex]);
    }
  }
  return CoverageDirectory(
    path: _directoryPath(prefix),
    directories: [
      for (final segment in childOrder)
        _subtree([...prefix, segment], childFiles[segment]!),
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
  return path.posix.joinAll(segments);
}

List<String> _parentSegments(String filePath) {
  final parts = path.posix.split(filePath);
  if (parts.length <= 1) return const [];
  return parts.sublist(0, parts.length - 1);
}
