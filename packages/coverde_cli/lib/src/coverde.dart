import 'package:coverde/coverde.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';

/// The command invocation function that provides coverage-related
/// functionalities.
Future<void> coverde({
  required List<String> args,
  required Logger logger,
  required String globalLockFilePath,
  required String pubApiBaseUrl,
  required http.Client httpClient,
  required String rawDartVersion,
}) async {
  final packageVersionManagerDependencies = PackageVersionManagerDependencies(
    logger: logger,
    httpClient: httpClient,
    globalLockFilePath: globalLockFilePath,
    baseUrl: pubApiBaseUrl,
    rawDartVersion: rawDartVersion,
  );
  await CoverdeCommandRunner(
    packageVersionManager: PackageVersionManager(
      dependencies: packageVersionManagerDependencies,
    ),
    logger: logger,
  ).run(args);
}
