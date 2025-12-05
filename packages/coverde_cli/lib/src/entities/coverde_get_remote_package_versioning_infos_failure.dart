/// {@template coverde_cli.coverde_get_remote_package_versioning_infos_failure}
/// A failure that occurs when retrieving the remote package versioning infos
/// fails.
/// {@endtemplate}
sealed class CoverdeGetRemotePackageVersioningInfosFailure
    implements Exception {
  const CoverdeGetRemotePackageVersioningInfosFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.unexpected_remote_package_versioning_infos_retrieval_failure}
/// A failure that occurs when the remote package versioning infos retrieval
/// fails.
/// {@endtemplate}
final class UnexpectedRemotePackageVersioningInfosRetrievalFailure
    extends CoverdeGetRemotePackageVersioningInfosFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.unexpected_remote_package_versioning_infos_retrieval_failure}
  const UnexpectedRemotePackageVersioningInfosRetrievalFailure();
}

/// {@template coverde_cli.invalid_remote_package_versioning_info_failure}
/// A failure that occurs when the remote package versioning info is invalid.
/// {@endtemplate}
sealed class InvalidRemotePackageVersioningInfoFailure
    extends CoverdeGetRemotePackageVersioningInfosFailure {
  const InvalidRemotePackageVersioningInfoFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_remote_package_versioning_info_member_type_failure}
/// A failure that occurs when the remote package versioning info member is not
/// of the expected type.
/// {@endtemplate}
final class InvalidRemotePackageVersioningInfoMemberTypeFailure
    extends InvalidRemotePackageVersioningInfoFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.invalid_remote_package_versioning_info_member_type_failure}
  const InvalidRemotePackageVersioningInfoMemberTypeFailure({
    required this.key,
    required this.expectedType,
    required this.value,
  });

  /// The key of the member with the invalid type.
  ///
  /// If `null`, the invalid member is the root member.
  final String? key;

  /// The expected type of the member with the invalid type.
  final Type expectedType;

  /// The value of the member with the invalid type.
  final dynamic value;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde_cli.invalid_remote_package_versioning_info_member_value_failure}
/// A failure that occurs when the remote package versioning info member value
/// is invalid.
/// {@endtemplate}
final class InvalidRemotePackageVersioningInfoMemberValueFailure
    extends InvalidRemotePackageVersioningInfoFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde_cli.invalid_remote_package_versioning_info_member_value_failure}
  const InvalidRemotePackageVersioningInfoMemberValueFailure({
    required this.key,
    required this.value,
    this.hint,
  });

  /// The key of the member with the invalid value.
  ///
  /// If `null`, the invalid member is the root member.
  final String? key;

  /// The value of the member with the invalid value.
  final dynamic value;

  /// A hint to identify the invalid value.
  final String? hint;
}
