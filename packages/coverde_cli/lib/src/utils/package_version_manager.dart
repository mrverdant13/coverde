import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:universal_io/universal_io.dart';

/// {@template coverde_cli.package_version_manager}
/// A manager for checking and updating the version of a package.
/// {@endtemplate}
class PackageVersionManager {
  /// {@macro coverde_cli.package_version_manager}
  const PackageVersionManager({
    required this.dependencies,
  });

  /// A regex to match the entry of a package in the package lock file.
  static final packageLockEntryPattern = RegExp(
    r'''^ {4}dependency:\s*["']?direct main["']?$.*? {6}name:\s*(?<packageName>[a-zA-Z_][a-zA-Z0-9_]*)$.*? {6}url:\s*["']?https:\/\/pub\.dev["']?$.*? {4}source:\s*["']?hosted["']?$.*? {4}version:\s*["']?(?<packageVersion>[^"'\n]+)["']?$''',
    multiLine: true,
    dotAll: true,
  );

  /// A regex to match the version constraint of the Dart SDK in the package
  /// lock file.
  static final dartVersionConstraintRegex = RegExp(
    r'''^sdks:(?:.|\n)*?dart:\s*["']?(?<versionConstraint>[^"'\n]+)["']?''',
    multiLine: true,
    dotAll: true,
  );

  /// The internal dependencies.
  final PackageVersionManagerDependencies dependencies;

  /// {@macro coverde_cli.package_version_manager_dependencies.logger}
  @visibleForTesting
  Logger get logger => dependencies.logger;

  /// {@macro coverde_cli.package_version_manager_dependencies.http_client}
  @visibleForTesting
  http.Client get httpClient => dependencies.httpClient;

  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.package_version_manager_dependencies.global_lock_file_path}
  @visibleForTesting
  String get globalLockFilePath => dependencies.globalLockFilePath;

  /// {@macro coverde_cli.package_version_manager_dependencies.base_url}
  @visibleForTesting
  String get baseUrl => dependencies.baseUrl;

  /// {@macro coverde_cli.package_version_manager_dependencies.raw_dart_version}
  @visibleForTesting
  String get rawDartVersion => dependencies.rawDartVersion;

  /// Get the global versioning info of the running package.
  ///
  /// Returns `null` if the package is not globally installed via\
  /// `dart pub global activate`.
  @visibleForTesting
  Future<PackageVersioningInfo?> getGlobalPackageInstallationInfo() async {
    final lockFile = File(globalLockFilePath);
    if (!lockFile.existsSync()) return null;
    if (!FileSystemEntity.isFileSync(globalLockFilePath)) return null;
    final lockFileContent = await lockFile.readAsString();
    final packageLockEntryMatch =
        packageLockEntryPattern.firstMatch(lockFileContent);
    if (packageLockEntryMatch == null) return null;
    final packageName = packageLockEntryMatch.namedGroup('packageName')!;
    final rawPackageVersion =
        packageLockEntryMatch.namedGroup('packageVersion')!;
    final packageVersion = Version.parse(rawPackageVersion);
    final dartVersionConstraintMatch =
        dartVersionConstraintRegex.firstMatch(lockFileContent);
    if (dartVersionConstraintMatch == null) return null;
    final rawDartVersionConstraint =
        dartVersionConstraintMatch.namedGroup('versionConstraint');
    if (rawDartVersionConstraint == null) return null;
    final dartVersionConstraint =
        VersionConstraint.parse(rawDartVersionConstraint);
    return PackageVersioningInfo(
      packageName: packageName,
      packageVersion: packageVersion,
      dartVersionConstraint: dartVersionConstraint,
    );
  }

  /// Get the [PackageVersioningInfo]s of a remote package.
  @visibleForTesting
  Future<Iterable<PackageVersioningInfo>> getRemotePackageVersioningInfos(
    String packageName,
  ) async {
    final packageInfoUri = Uri.parse('$baseUrl/api/packages/$packageName');
    final packageInfoResponse = await httpClient
        .get(packageInfoUri)
        .timeout(const Duration(seconds: 5));
    if (packageInfoResponse.statusCode != HttpStatus.ok) {
      throw Exception(
        'Failed to get remote package versioning info',
      );
    }
    final rawPackageInfoResponse =
        jsonDecode(packageInfoResponse.body) as Map<String, dynamic>;
    final rawVersions = rawPackageInfoResponse['versions'] as List<dynamic>;

    PackageVersioningInfo parsePackageVersioningInfo(
      Map<String, dynamic> rawVersionInfo,
    ) {
      final rawPubspec = rawVersionInfo['pubspec'] as Map<String, dynamic>;
      final rawVersion = rawVersionInfo['version'] as String;
      final version = Version.parse(rawVersion);
      final rawEnvironment = rawPubspec['environment'] as Map<String, dynamic>;
      final rawDartVersionConstraint = rawEnvironment['sdk'] as String;
      final dartVersionConstraint =
          VersionConstraint.parse(rawDartVersionConstraint);
      return PackageVersioningInfo(
        packageName: packageName,
        packageVersion: version,
        dartVersionConstraint: dartVersionConstraint,
      );
    }

    return rawVersions.reversed
        .cast<Map<String, dynamic>>()
        .map(parsePackageVersioningInfo);
  }

  /// Prompts the user to update the package, if possible.
  Future<void> promptUpdate() async {
    Timer? logsTimer;

    try {
      Progress logPeriodically({required String message}) {
        final progress = logger.progress(message);
        logsTimer?.cancel();
        logsTimer = Timer.periodic(
          const Duration(milliseconds: 100),
          (timer) {
            if (!timer.isActive) return;
            progress.update(message);
          },
        );
        return progress;
      }

      const globalPackageInstallationInfoRetrievalMessage =
          'Reviewing global package installation info...';
      final globalPackageInstallationInfoRetrievalProgress = logPeriodically(
        message: globalPackageInstallationInfoRetrievalMessage,
      );
      final currentPackageInstallationInfo =
          await getGlobalPackageInstallationInfo();
      globalPackageInstallationInfoRetrievalProgress.cancel();
      if (currentPackageInstallationInfo == null) {
        logger.warn('No global package installation info found.');
        return;
      }
      final currentPackageVersion =
          currentPackageInstallationInfo.packageVersion;
      final packageName = currentPackageInstallationInfo.packageName;
      logger.detail(
        'Global package installation info found:     '
        '$packageName @ $currentPackageVersion',
      );

      const remotePackageVersioningInfosRetrievalMessage =
          'Reviewing remote package versioning infos...';
      final remotePackageVersioningInfosRetrievalProgress = logPeriodically(
        message: remotePackageVersioningInfosRetrievalMessage,
      );
      final remotePackageVersioningInfos =
          await getRemotePackageVersioningInfos(packageName);
      remotePackageVersioningInfosRetrievalProgress.cancel();

      final dartVersion = Version.parse(
        rawDartVersion.split(' ').first,
      );
      final latestCompatiblePackageVersioningInfo =
          remotePackageVersioningInfos.takeWhile(
        (remotePackageVersioningInfo) {
          final remotePackageVersion =
              remotePackageVersioningInfo.packageVersion;
          if (!remotePackageVersion.isPreRelease &&
              currentPackageVersion.isPreRelease) {
            return false;
          }
          return remotePackageVersion > currentPackageVersion;
        },
      ).firstWhereOrNull(
        (remotePackageVersioningInfo) {
          final isDartVersionConstraintAllowed = remotePackageVersioningInfo
              .dartVersionConstraint
              .allows(dartVersion);
          return isDartVersionConstraintAllowed;
        },
      );
      if (latestCompatiblePackageVersioningInfo == null) {
        logger.warn(
          'No newer compatible version of `$packageName` is available.',
        );
        return;
      }
      final latestVersion =
          latestCompatiblePackageVersioningInfo.packageVersion;
      logger
        ..detail(
          'A newer compatible version is available: '
          '$packageName @ $latestVersion',
        )
        ..detail(
          '''Dart SDK constraint: ${latestCompatiblePackageVersioningInfo.dartVersionConstraint}''',
        );
      final unstyledUpdateMessage =
          'A new version of `$packageName` is available!';
      final styledUpdateMessage = lightYellow.wrap(unstyledUpdateMessage)!;
      final styledVersionsMessage = '''
${lightGray.wrap(currentPackageVersion.toString())} \u2192 ${lightGreen.wrap(latestVersion.toString())}''';
      final unstyledVersionsMessage = '''
$currentPackageVersion \u2192 $latestVersion''';

      final unstyledCommand =
          'dart pub global activate $packageName $latestVersion';
      final styledCommand = wrapWith(
        unstyledCommand,
        [lightCyan, styleBold],
      )!;
      String buildCommandMessage(String command) => 'Run $command to update.';
      final styledCommandMessage = buildCommandMessage(styledCommand);
      final unstyledCommandMessage = buildCommandMessage(unstyledCommand);

      // Calculate padding for version display to center it in the box
      final boxLength = [
            unstyledUpdateMessage.length,
            unstyledCommandMessage.length,
          ].max +
          4;

      String addPadding(String unstyled, String styled) {
        final totalPadding = boxLength - unstyled.length;
        final leftPadding = totalPadding ~/ 2;
        final rightPadding = totalPadding - leftPadding;
        return ' ' * leftPadding + styled + ' ' * rightPadding;
      }

      final messageBuffer = StringBuffer()
        ..writeln(
          '┏${'━' * boxLength}┓',
        )
        ..writeln(
          '┃${' ' * boxLength}┃',
        )
        ..writeln(
          '┃${addPadding(unstyledUpdateMessage, styledUpdateMessage)}┃',
        )
        ..writeln(
          '┃${addPadding(unstyledVersionsMessage, styledVersionsMessage)}┃',
        )
        ..writeln(
          '┃${addPadding(unstyledCommandMessage, styledCommandMessage)}┃',
        )
        ..writeln(
          '┃${' ' * boxLength}┃',
        )
        ..writeln(
          '┗${'━' * boxLength}┛',
        );
      logger.write(messageBuffer.toString());
    } on Object catch (e) {
      logger.alert('Failed to prompt update: $e');
    } finally {
      logsTimer?.cancel();
    }
  }
}
