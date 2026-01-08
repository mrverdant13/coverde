import 'package:universal_io/universal_io.dart';
import 'package:yaml/yaml.dart';

/// {@template coverde_cli.coverde_get_global_package_installation_info_failure}
/// A failure that occurs when retrieving the global package installation info
/// fails.
/// {@endtemplate}
sealed class CoverdeGetGlobalPackageInstallationInfoFailure
    implements Exception {
  const CoverdeGetGlobalPackageInstallationInfoFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.absent_global_lock_file_for_global_installation_failure}
/// A failure that occurs when the global lock file is absent.
/// {@endtemplate}
final class AbsentGlobalLockFileForGlobalInstallationFailure
    extends CoverdeGetGlobalPackageInstallationInfoFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.absent_global_lock_file_for_global_installation_failure}
  const AbsentGlobalLockFileForGlobalInstallationFailure({
    required this.lockFile,
  });

  /// The global lock file that is absent.
  final File lockFile;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.unreadable_global_lock_file_for_global_installation_failure}
/// A failure that occurs when the global lock file is unreadable.
/// {@endtemplate}
final class UnreadableGlobalLockFileForGlobalInstallationFailure
    extends CoverdeGetGlobalPackageInstallationInfoFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.unreadable_global_lock_file_for_global_installation_failure}
  const UnreadableGlobalLockFileForGlobalInstallationFailure({
    required this.lockFile,
    required this.fileSystemException,
  });

  /// The global lock file that is unreadable.
  final File lockFile;

  /// The file system exception that occurred.
  final FileSystemException fileSystemException;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_global_lock_file_content_for_global_installation_failure}
/// A failure that occurs when the global lock file is invalid.
/// {@endtemplate}
sealed class InvalidGlobalLockFileContentForGlobalInstallationFailure
    extends CoverdeGetGlobalPackageInstallationInfoFailure {
  const InvalidGlobalLockFileContentForGlobalInstallationFailure({
    required this.lockFile,
  });

  /// The global lock file that is invalid.
  final File lockFile;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_global_lock_file_yaml_for_global_installation_failure}
/// A failure that occurs when the global lock file is invalid.
/// {@endtemplate}
final class InvalidGlobalLockFileYamlForGlobalInstallationFailure
    extends InvalidGlobalLockFileContentForGlobalInstallationFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.invalid_global_lock_file_yaml_for_global_installation_failure}
  const InvalidGlobalLockFileYamlForGlobalInstallationFailure({
    required super.lockFile,
    required this.yamlException,
  });

  /// The yaml exception that occurred.
  final YamlException yamlException;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_global_lock_member_type_for_global_installation_failure}
/// A failure that occurs when the global lock member is not of the expected
/// type.
/// {@endtemplate}
final class InvalidGlobalLockMemberTypeForGlobalInstallationFailure
    extends InvalidGlobalLockFileContentForGlobalInstallationFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.invalid_global_lock_member_type_for_global_installation_failure}
  const InvalidGlobalLockMemberTypeForGlobalInstallationFailure({
    required super.lockFile,
    required this.key,
    required this.expectedType,
    required this.value,
  });

  /// The key of the content with the invalid type.
  ///
  /// If `null`, the invalid content is the root content.
  final String? key;

  /// The expected type of the invalid content.
  final Type expectedType;

  /// The invalid content.
  final dynamic value;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_global_lock_member_value_for_global_installation_failure}
/// A failure that occurs when the global lock member value is invalid.
/// {@endtemplate}
final class InvalidGlobalLockMemberValueForGlobalInstallationFailure
    extends InvalidGlobalLockFileContentForGlobalInstallationFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.invalid_global_lock_member_value_for_global_installation_failure}
  const InvalidGlobalLockMemberValueForGlobalInstallationFailure({
    required super.lockFile,
    required this.key,
    required this.value,
    this.hint,
  });

  /// The key of the content with the invalid value.
  ///
  /// If `null`, the invalid content is the root content.
  final String? key;

  /// The invalid value.
  final dynamic value;

  /// A hint to identify the invalid value.
  final String? hint;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.no_direct_main_hosted_package_for_global_installation_failure}
/// A failure that occurs when the global lock file does not contain a direct
/// main hosted package within its registered packages.
/// {@endtemplate}
final class NoDirectMainHostedPackageForGlobalInstallationFailure
    extends InvalidGlobalLockFileContentForGlobalInstallationFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.no_direct_main_hosted_package_for_global_installation_failure}
  const NoDirectMainHostedPackageForGlobalInstallationFailure({
    required super.lockFile,
  });
}
