import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
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
  await CoverdeCommandRunner(logger: logger).run(args);
  final packageVersionManagerDependencies = PackageVersionManagerDependencies(
    logger: logger,
    httpClient: httpClient,
    globalLockFilePath: globalLockFilePath,
    baseUrl: pubApiBaseUrl,
    rawDartVersion: rawDartVersion,
  );
  final packageVersionManager = PackageVersionManager(
    dependencies: packageVersionManagerDependencies,
  );
  await _checkUpdates(packageVersionManager);
}

Future<void> _checkUpdates(
  PackageVersionManager packageVersionManager,
) async {
  try {
    await packageVersionManager.promptUpdate();
  } on Object catch (_) {
    // Swallow the error.
  }
}
