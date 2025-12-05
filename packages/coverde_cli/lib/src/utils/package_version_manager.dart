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
import 'package:yaml/yaml.dart' as yaml;

/// {@template coverde_cli.package_version_manager}
/// A manager for checking and updating the version of a package.
/// {@endtemplate}
class PackageVersionManager {
  /// {@macro coverde_cli.package_version_manager}
  const PackageVersionManager({
    required this.dependencies,
  });

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
  Future<PackageVersioningInfo> getGlobalPackageInstallationInfo() async {
    final lockFile = File(globalLockFilePath);
    if (!FileSystemEntity.isFileSync(globalLockFilePath)) {
      throw AbsentGlobalLockFileForGlobalInstallationFailure(
        lockFile: lockFile,
      );
    }
    final lockFileContent = await lockFile.readAsString();
    final rawLockFileYaml = yaml.loadYaml(lockFileContent);
    if (rawLockFileYaml is! yaml.YamlMap) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: null,
        value: rawLockFileYaml,
        expectedType: yaml.YamlMap,
      );
    }
    final rawPackages = rawLockFileYaml['packages'];
    if (rawPackages is! yaml.YamlMap) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: 'packages',
        expectedType: yaml.YamlMap,
        value: rawPackages,
      );
    }
    late final yaml.YamlMap? rawDirectMainHostedPackage;
    try {
      final rawPackagesYamls = rawPackages.values.cast<yaml.YamlMap>();
      rawDirectMainHostedPackage = rawPackagesYamls.firstWhereOrNull(
        (rawPackage) =>
            rawPackage['dependency'] == 'direct main' &&
            rawPackage['source'] == 'hosted',
      );
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
          lockFile: lockFile,
          key: 'packages(values)',
          expectedType: Iterable<yaml.YamlMap>,
          value: rawPackages,
        ),
        stackTrace,
      );
    }
    if (rawDirectMainHostedPackage == null) {
      throw NoDirectMainHostedPackageForGlobalInstallationFailure(
        lockFile: lockFile,
      );
    }
    final rawPackageDescription = rawDirectMainHostedPackage['description'];
    if (rawPackageDescription is! yaml.YamlMap) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: [
          'packages',
          '["dependency"="direct main", "source"="hosted"]',
          'description',
        ].join('.'),
        expectedType: yaml.YamlMap,
        value: rawPackageDescription,
      );
    }
    final packageName = rawPackageDescription['name'];
    if (packageName is! String) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: [
          'packages',
          '["dependency"="direct main", "source"="hosted"]',
          'description',
          'name',
        ].join('.'),
        expectedType: String,
        value: packageName,
      );
    }
    final packageHostUrl = rawPackageDescription['url'];
    if (packageHostUrl is! String) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: [
          'packages',
          '["dependency"="direct main", "source"="hosted"]',
          'description',
          'url',
        ].join('.'),
        expectedType: String,
        value: packageHostUrl,
      );
    }
    if (Uri.tryParse(packageHostUrl) != Uri.tryParse(baseUrl)) {
      throw InvalidGlobalLockMemberValueForGlobalInstallationFailure(
        lockFile: lockFile,
        key: [
          'packages',
          '["dependency"="direct main", "source"="hosted"]',
          'description',
          'url',
        ].join('.'),
        value: packageHostUrl,
        hint: 'equal to $baseUrl',
      );
    }
    final rawPackageVersion = rawDirectMainHostedPackage['version'];
    if (rawPackageVersion is! String) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: [
          'packages',
          '["dependency"="direct main", "source"="hosted"]',
          'version',
        ].join('.'),
        expectedType: String,
        value: rawPackageVersion,
      );
    }
    late final Version packageVersion;
    try {
      packageVersion = Version.parse(rawPackageVersion);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        InvalidGlobalLockMemberValueForGlobalInstallationFailure(
          lockFile: lockFile,
          key: [
            'packages',
            '["dependency"="direct main", "source"="hosted"]',
            'version',
          ].join('.'),
          value: rawPackageVersion,
          hint: 'a valid SemVer string',
        ),
        stackTrace,
      );
    }
    final rawSdks = rawLockFileYaml['sdks'];
    if (rawSdks is! yaml.YamlMap) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: 'sdks',
        expectedType: yaml.YamlMap,
        value: rawSdks,
      );
    }
    final rawDartVersionConstraint = rawSdks['dart'];
    if (rawDartVersionConstraint is! String) {
      throw InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
        lockFile: lockFile,
        key: 'sdks.dart',
        expectedType: String,
        value: rawDartVersionConstraint,
      );
    }
    late final VersionConstraint dartVersionConstraint;
    try {
      dartVersionConstraint = VersionConstraint.parse(rawDartVersionConstraint);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        InvalidGlobalLockMemberValueForGlobalInstallationFailure(
          lockFile: lockFile,
          key: 'sdks.dart',
          value: rawDartVersionConstraint,
          hint: 'a valid SemVer constraint string',
        ),
        stackTrace,
      );
    }
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
    late final http.Response packageInfoResponse;
    try {
      final packageInfoUri = Uri.parse('$baseUrl/api/packages/$packageName');
      packageInfoResponse = await httpClient
          .get(packageInfoUri)
          .timeout(const Duration(seconds: 5));
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const UnexpectedRemotePackageVersioningInfosRetrievalFailure(),
        stackTrace,
      );
    }
    if (packageInfoResponse.statusCode != HttpStatus.ok) {
      throw const UnexpectedRemotePackageVersioningInfosRetrievalFailure();
    }
    final rawPackageInfoResponse = jsonDecode(packageInfoResponse.body);
    if (rawPackageInfoResponse is! Map<String, dynamic>) {
      throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
        key: null,
        expectedType: Map<String, dynamic>,
        value: rawPackageInfoResponse,
      );
    }
    final rawVersions = rawPackageInfoResponse['versions'];
    if (rawVersions is! List) {
      throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
        key: 'versions',
        expectedType: List,
        value: rawVersions,
      );
    }

    PackageVersioningInfo parsePackageVersioningInfo(
      int index,
      dynamic rawVersionInfo,
    ) {
      if (rawVersionInfo is! Map<String, dynamic>) {
        throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
          key: [
            'versions',
            '[$index]',
          ].join('.'),
          expectedType: Map<String, dynamic>,
          value: rawVersionInfo,
        );
      }
      final rawVersion = rawVersionInfo['version'];
      if (rawVersion is! String) {
        throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
          key: [
            'versions',
            '[$index]',
            'version',
          ].join('.'),
          expectedType: String,
          value: rawVersion,
        );
      }
      late final Version version;
      try {
        version = Version.parse(rawVersion);
      } on Object catch (_, stackTrace) {
        Error.throwWithStackTrace(
          InvalidRemotePackageVersioningInfoMemberValueFailure(
            key: [
              'versions',
              '[$index]',
              'version',
            ].join('.'),
            value: rawVersion,
            hint: 'a valid SemVer string',
          ),
          stackTrace,
        );
      }
      final rawPubspec = rawVersionInfo['pubspec'];
      if (rawPubspec is! Map<String, dynamic>) {
        throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
          key: [
            'versions',
            '[$index]',
            'pubspec',
          ].join('.'),
          expectedType: Map<String, dynamic>,
          value: rawPubspec,
        );
      }
      final rawEnvironment = rawPubspec['environment'];
      if (rawEnvironment is! Map<String, dynamic>) {
        throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
          key: [
            'versions',
            '[$index]',
            'pubspec',
            'environment',
          ].join('.'),
          expectedType: Map<String, dynamic>,
          value: rawEnvironment,
        );
      }
      final rawDartVersionConstraint = rawEnvironment['sdk'];
      if (rawDartVersionConstraint is! String) {
        throw InvalidRemotePackageVersioningInfoMemberTypeFailure(
          key: [
            'versions',
            '[$index]',
            'pubspec',
            'environment',
            'sdk',
          ].join('.'),
          expectedType: String,
          value: rawDartVersionConstraint,
        );
      }
      late final VersionConstraint dartVersionConstraint;
      try {
        dartVersionConstraint =
            VersionConstraint.parse(rawDartVersionConstraint);
      } on Object catch (_, stackTrace) {
        Error.throwWithStackTrace(
          InvalidRemotePackageVersioningInfoMemberValueFailure(
            key: [
              'versions',
              '[$index]',
              'pubspec',
              'environment',
              'sdk',
            ].join('.'),
            value: rawDartVersionConstraint,
            hint: 'a valid SemVer constraint string',
          ),
          stackTrace,
        );
      }
      return PackageVersioningInfo(
        packageName: packageName,
        packageVersion: version,
        dartVersionConstraint: dartVersionConstraint,
      );
    }

    return rawVersions.reversed.mapIndexed(parsePackageVersioningInfo);
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
      late final PackageVersioningInfo currentPackageInstallationInfo;
      currentPackageInstallationInfo = await getGlobalPackageInstallationInfo();
      globalPackageInstallationInfoRetrievalProgress.cancel();
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
      late final Iterable<PackageVersioningInfo> remotePackageVersioningInfos;
      remotePackageVersioningInfos =
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
      if (e is CoverdeGetGlobalPackageInstallationInfoFailure) {
        logger.logGlobalPackageInstallationInfoRetrievalFailure(e);
      }
      if (e is CoverdeGetRemotePackageVersioningInfosFailure) {
        logger.logRemotePackageVersioningInfosRetrievalFailure(e);
      }
      logger.alert('Failed to prompt update');
    } finally {
      logsTimer?.cancel();
    }
  }
}

/// Extension for logging [PackageVersionManager] failures.
extension PackageVersionManagerLogger on Logger {
  /// Log a [CoverdeGetGlobalPackageInstallationInfoFailure].
  void logGlobalPackageInstallationInfoRetrievalFailure(
    CoverdeGetGlobalPackageInstallationInfoFailure failure,
  ) {
    switch (failure) {
      case AbsentGlobalLockFileForGlobalInstallationFailure(:final lockFile):
        warn(
          'Absent global lock file (`${lockFile.path}`). '
          'It is likely `dart pub global activate` '
          'was not used to install the package.',
        );
      case final InvalidGlobalLockFileContentForGlobalInstallationFailure
        failure:
        final details = switch (failure) {
          InvalidGlobalLockMemberTypeForGlobalInstallationFailure(
            :final key,
            :final value,
            :final expectedType,
          ) =>
            'The `$key` member is '
                'expected to be a `$expectedType`. '
                'Actual value: `$value`.',
          InvalidGlobalLockMemberValueForGlobalInstallationFailure(
            :final key,
            :final value,
            :final hint,
          ) =>
            'The `$key` member value is '
                '${hint != null ? 'expected to be $hint' : 'invalid'}'
                '. '
                'Actual value: `$value`.',
          NoDirectMainHostedPackageForGlobalInstallationFailure() =>
            'No direct main hosted package found.',
        };
        err('Invalid global lock file content. $details');
    }
  }

  /// Log a [CoverdeGetRemotePackageVersioningInfosFailure].
  void logRemotePackageVersioningInfosRetrievalFailure(
    CoverdeGetRemotePackageVersioningInfosFailure failure,
  ) {
    switch (failure) {
      case UnexpectedRemotePackageVersioningInfosRetrievalFailure():
        err('Unexpected remote package versioning infos retrieval');
      case final InvalidRemotePackageVersioningInfoFailure failure:
        final details = switch (failure) {
          InvalidRemotePackageVersioningInfoMemberTypeFailure(
            :final key,
            :final value,
            :final expectedType,
          ) =>
            'The `$key` member is '
                'expected to be a `$expectedType`. '
                'Actual value: `$value`.',
          InvalidRemotePackageVersioningInfoMemberValueFailure(
            :final key,
            :final value,
            :final hint,
          ) =>
            'The `$key` member value is '
                '${hint != null ? 'expected to be $hint' : 'invalid'}'
                '. '
                'Actual value: `$value`.',
        };
        err('Invalid remote package versioning info. $details');
    }
  }
}
