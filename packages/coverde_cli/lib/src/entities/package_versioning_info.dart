import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';

/// {@template coverde_cli.package_versioning_info}
/// Information about the versioning of a package.
/// {@endtemplate}
@immutable
class PackageVersioningInfo {
  /// {@macro coverde_cli.package_versioning_info}
  const PackageVersioningInfo({
    required this.packageName,
    required this.packageVersion,
    required this.dartVersionConstraint,
  });

  /// The name of the package.
  final String packageName;

  /// The version of the package.
  final Version packageVersion;

  /// The version constraint of the Dart SDK.
  final VersionConstraint dartVersionConstraint;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PackageVersioningInfo) return false;
    return packageName == other.packageName &&
        packageVersion == other.packageVersion &&
        dartVersionConstraint == other.dartVersionConstraint;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        packageName,
        packageVersion,
        dartVersionConstraint,
      ]);

  @override
  String toString() {
    return 'PackageVersioningInfo('
        'packageName: $packageName, '
        'packageVersion: $packageVersion, '
        'dartVersionConstraint: $dartVersionConstraint'
        ')';
  }
}
