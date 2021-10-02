import 'dart:io';
import 'package:path/path.dart' as p;

/// CLI folder path.
final _covUtilsPath = Platform.script.pathSegments
    .takeWhile((segment) => segment != 'bin')
    .reduce(p.join);

/// CLI assets folder path.
final assetsPath = p.join(
  _covUtilsPath,
  'lib/assets',
);
