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
    while (index < fewest) {
      final group = <String>{
        for (final parent in parents)
          if (parent.length > index) parent[index],
      };
      if (group.length != 1) break;
      prefix.add(group.single);
      index++;
    }
  }
  final nextSegments = <String>[];
  final seenSegments = <String>{};
  for (final parent in parents) {
    if (parent.length <= index) continue;
    final segment = parent[index];
    if (seenSegments.add(segment)) nextSegments.add(segment);
  }
  final basePath = _directoryPath(prefix);
  return CoverageDirectory(
    path: basePath,
    directories: [
      for (final segment in nextSegments)
        _subtree(
          [...prefix, segment],
          [
            for (final file in files)
              if (_isWithin([...prefix, segment], file.path)) file,
          ],
        ),
    ],
    files: [
      for (final file in files)
        if (_directoryPath(_parentSegments(file.path)) == basePath) file,
    ],
  );
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

bool _isWithin(List<String> base, String path) {
  final parent = _parentSegments(path);
  if (parent.length < base.length) return false;
  for (var index = 0; index < base.length; index++) {
    if (parent[index] != base[index]) return false;
  }
  return true;
}
