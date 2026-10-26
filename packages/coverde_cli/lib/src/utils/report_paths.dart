import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:path/path.dart' as path;

/// Report-relative paths for coverage files that are not relative.
///
/// POSIX absolute paths use `absolute` (`absolute-2` when that name is taken).
/// A drive root uses `drive-c`. A drive-relative path uses `drive-c-relative`.
/// A UNC root uses `unc-<server>-<share>`.
final class ReportPaths {
  /// Creates an empty layout.
  ReportPaths();

  String _absoluteNamespace = 'absolute';
  final Map<String, String> _driveNamespaces = <String, String>{};
  final Map<String, String> _driveRelativeNamespaces = <String, String>{};
  final Map<String, String> _uncNamespaces = <String, String>{};

  static final _driveLetter = RegExp('^([A-Za-z]):');
  static final _uncRoot = RegExp(r'^//([^/]+)/([^/]+)(.*)$');

  /// Records every path in [root], including directories.
  void collectTree(CoverageDirectory root) {
    final paths = <String>[];
    void visit(CoverageDirectory directory) {
      paths.add(directory.path);
      directory.directories.forEach(visit);
      for (final file in directory.files) {
        paths.add(file.path);
      }
    }

    visit(root);
    collectPaths(paths);
  }

  /// Records [sourcePaths] so a later [relative] name does not collide.
  void collectPaths(Iterable<String> sourcePaths) {
    final used = <String>{};
    final rootedDrives = <String>{};
    final relativeDrives = <String>{};
    final uncRoots = <String>{};
    for (final sourcePath in sourcePaths) {
      final normalized = coveragePathSlashForm(
        normalizeCoveragePath(sourcePath),
      );
      final unc = _uncKey(normalized);
      final drive = driveLetter(normalized);
      if (unc != null) {
        uncRoots.add(unc);
      } else if (drive != null) {
        if (_isDriveRelative(normalized)) {
          relativeDrives.add(drive);
        } else {
          rootedDrives.add(drive);
        }
      } else if (!path.posix.isAbsolute(normalized)) {
        final parts = path.posix.split(normalized);
        if (parts.isNotEmpty && parts.first != '.' && parts.first != '..') {
          used.add(parts.first);
        }
      }
    }

    _absoluteNamespace = _freeName(used, 'absolute');
    used.add(_absoluteNamespace);
    for (final drive in rootedDrives) {
      final namespace = _freeName(used, 'drive-$drive');
      _driveNamespaces[drive] = namespace;
      used.add(namespace);
    }
    for (final drive in relativeDrives) {
      final namespace = _freeName(used, 'drive-$drive-relative');
      _driveRelativeNamespaces[drive] = namespace;
      used.add(namespace);
    }
    for (final root in uncRoots) {
      final namespace = _freeName(used, root);
      _uncNamespaces[root] = namespace;
      used.add(namespace);
    }
  }

  /// The destination-relative path of [target] as seen from [from].
  String relative(String target, {String from = '.'}) {
    final to = coveragePathSlashForm(normalizeCoveragePath(target));
    final base = coveragePathSlashForm(normalizeCoveragePath(from));
    if (base.isEmpty || base == '.') {
      final unc = _uncRoot.firstMatch(to);
      if (unc != null) {
        final key = _uncKey(to)!;
        final namespace = _uncNamespaces[key] ?? key;
        final rest = (unc.group(3) ?? '').replaceFirst(RegExp('^/+'), '');
        if (rest.isEmpty) return namespace;
        return path.posix.join(namespace, rest);
      }
      if (path.posix.isAbsolute(to)) {
        final stripped = path.posix.relative(to, from: '/');
        if (stripped == '.') return _absoluteNamespace;
        return path.posix.join(_absoluteNamespace, stripped);
      }
      final drive = driveLetter(to);
      if (drive != null) {
        final relativeDrive = _isDriveRelative(to);
        final namespace = relativeDrive
            ? (_driveRelativeNamespaces[drive] ?? 'drive-$drive-relative')
            : (_driveNamespaces[drive] ?? 'drive-$drive');
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

  /// The lowercase drive letter of a slash-form coverage path.
  static String? driveLetter(String normalized) {
    return _driveLetter.firstMatch(normalized)?.group(1)?.toLowerCase();
  }

  static String? _uncKey(String normalized) {
    final match = _uncRoot.firstMatch(normalized);
    if (match == null) return null;
    final server = match.group(1)!.toLowerCase();
    final share = match.group(2)!.toLowerCase();
    return 'unc-$server-$share';
  }

  /// `C:a.dart` is relative to the current directory on that drive.
  /// `C:` and `C:/a.dart` stay on the drive root.
  static bool _isDriveRelative(String normalized) {
    final drive = driveLetter(normalized);
    if (drive == null) return false;
    final rest = normalized.substring(drive.length + 1);
    return rest.isNotEmpty && !rest.startsWith('/');
  }

  static bool _nameTaken(Set<String> used, String candidate) {
    return used.any((name) => path.equals(name, candidate));
  }

  static String _freeName(Set<String> used, String base) {
    if (!_nameTaken(used, base)) return base;
    var suffix = 2;
    while (_nameTaken(used, '$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }
}
