import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Reads `name:` and `version:` from [pubspecFile].
///
/// Returns a structured error when either field is missing or empty.
({String? name, String? version, String? errorMessage})
    readPubspecNameAndVersion(
  File pubspecFile,
) {
  final parsed = _parsePubspecFile(pubspecFile);
  if (parsed.errorMessage != null) {
    return (name: null, version: null, errorMessage: parsed.errorMessage);
  }

  final pubspec = parsed.pubspec!;
  final version = pubspec.version;
  if (version == null) {
    return (
      name: null,
      version: null,
      errorMessage:
          'Could not read version from pubspec.yaml: ${pubspecFile.path}',
    );
  }

  return (
    name: pubspec.name,
    version: version.toString(),
    errorMessage: null,
  );
}

/// Reads the `version:` field from [pubspecFile].
///
/// Returns a structured error when the version cannot be read.
({String? version, String? errorMessage}) readPubspecVersion(File pubspecFile) {
  final parsed = _parsePubspecFile(pubspecFile);
  if (parsed.errorMessage != null) {
    return (version: null, errorMessage: parsed.errorMessage);
  }

  final version = parsed.pubspec!.version;
  if (version == null) {
    return (
      version: null,
      errorMessage:
          'Could not read version from pubspec.yaml: ${pubspecFile.path}',
    );
  }

  return (version: version.toString(), errorMessage: null);
}

/// Optional `repository:` and `issue_tracker:` values from [pubspecFile].
({String? repository, String? issueTracker}) readPubspecRepositoryFields(
  File pubspecFile,
) {
  final parsed = _parsePubspecFile(pubspecFile);
  if (parsed.errorMessage != null) {
    return (repository: null, issueTracker: null);
  }

  final pubspec = parsed.pubspec!;
  return (
    repository: pubspec.repository?.toString(),
    issueTracker: pubspec.issueTracker?.toString(),
  );
}

/// Replaces only the `version:` field in [pubspecContents].
///
/// Returns a structured error when the version field is missing or the YAML
/// cannot be updated.
({String? contents, String? errorMessage}) updatePubspecVersionLine({
  required String pubspecContents,
  required String newVersion,
}) {
  final parsed = _parsePubspecContents(pubspecContents);
  if (parsed.errorMessage != null) {
    return (contents: null, errorMessage: parsed.errorMessage);
  }

  if (parsed.pubspec!.version == null) {
    return (
      contents: null,
      errorMessage: 'Could not find version line in pubspec.yaml.',
    );
  }

  try {
    final editor = YamlEditor(pubspecContents)..update(['version'], newVersion);
    return (contents: editor.toString(), errorMessage: null);
  } on YamlException catch (error) {
    return (
      contents: null,
      errorMessage: 'Could not parse pubspec.yaml: ${error.message}',
    );
  }
}

({Pubspec? pubspec, String? errorMessage}) _parsePubspecFile(File pubspecFile) {
  return _parsePubspecContents(
    pubspecFile.readAsStringSync(),
    sourcePath: pubspecFile.path,
  );
}

({Pubspec? pubspec, String? errorMessage}) _parsePubspecContents(
  String contents, {
  String? sourcePath,
}) {
  try {
    return (
      pubspec: Pubspec.parse(
        contents,
        sourceUrl: sourcePath == null ? null : Uri.file(sourcePath),
      ),
      errorMessage: null,
    );
  } on ParsedYamlException catch (error) {
    if (_isMissingNameError(error)) {
      return (
        pubspec: null,
        errorMessage: sourcePath == null
            ? 'Could not read name from pubspec.yaml.'
            : 'Could not read name from pubspec.yaml: $sourcePath',
      );
    }

    return (
      pubspec: null,
      errorMessage: sourcePath == null
          ? 'Could not parse pubspec.yaml: ${error.message}'
          : 'Could not parse pubspec.yaml: $sourcePath (${error.message})',
    );
  }
}

bool _isMissingNameError(ParsedYamlException error) {
  return error.message.contains('Missing key "name"');
}
