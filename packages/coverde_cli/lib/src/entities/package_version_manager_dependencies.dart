import 'package:coverde/src/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

/// {@template coverde_cli.package_version_manager_dependencies}
/// Dependencies for a [PackageVersionManager].
/// {@endtemplate}
@immutable
class PackageVersionManagerDependencies {
  /// {@macro coverde_cli.package_version_manager_dependencies}
  const PackageVersionManagerDependencies({
    required this.logger,
    required this.httpClient,
    required this.globalLockFilePath,
    required this.baseUrl,
    required this.rawDartVersion,
  });

  /// {@template coverde_cli.package_version_manager_dependencies.logger}
  /// The logger to use to log messages.
  /// {@endtemplate}
  final Logger logger;

  /// {@template coverde_cli.package_version_manager_dependencies.http_client}
  /// The HTTP client to use to interact with the Pub API.
  /// {@endtemplate}
  final http.Client httpClient;

  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@template coverde_cli.package_version_manager_dependencies.global_lock_file_path}
  /// The lock file path of the global package.
  /// {@endtemplate}
  final String globalLockFilePath;

  /// {@template coverde_cli.package_version_manager_dependencies.base_url}
  /// The base URL of the Pub API.
  /// {@endtemplate}
  final String baseUrl;

  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@template coverde_cli.package_version_manager_dependencies.raw_dart_version}
  /// The raw Dart version.
  /// {@endtemplate}
  final String rawDartVersion;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PackageVersionManagerDependencies &&
        logger == other.logger &&
        httpClient == other.httpClient &&
        globalLockFilePath == other.globalLockFilePath &&
        baseUrl == other.baseUrl &&
        rawDartVersion == other.rawDartVersion;
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        logger,
        httpClient,
        globalLockFilePath,
        baseUrl,
        rawDartVersion,
      ]);
}
