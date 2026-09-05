/// Hardcoded package metadata for release tooling that has not yet adopted
/// `--cwd`. Used by `wait_for_pub_dev_version.dart`.
const packageConfigs = <String, PackageConfig>{
  'coverde': PackageConfig(
    packagePath: 'packages/coverde_cli',
    versionConstName: 'packageVersion',
  ),
};

class PackageConfig {
  const PackageConfig({
    required this.packagePath,
    required this.versionConstName,
  });

  final String packagePath;
  final String versionConstName;
}
