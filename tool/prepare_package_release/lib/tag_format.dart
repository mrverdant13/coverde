import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

/// Placeholder for the package version in a `--tag-format` template.
const versionPlaceholder = '{version}';

/// Placeholder for the package name in a `--tag-format` template.
const namePlaceholder = '{name}';

/// Semver-shaped segment captured from a tag via [parseVersionFromTag].
const semverCapturePattern =
    r'([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z]+)*)?(?:\+[0-9A-Za-z]+(?:\.[0-9A-Za-z]+)*)?)';

/// Characters that are invalid in git ref/tag literal segments.
final invalidGitRefLiteralPattern = RegExp(
  r'[\x00-\x1f\x7f ~^:?*[\]\\]|@{|\.\.',
);

/// Validates [format] for use as `--tag-format`.
///
/// The template must contain `{version}` exactly once and literal characters
/// must be valid git ref/tag characters.
String? validateTagFormat(String format) {
  final versionCount = versionPlaceholder.allMatches(format).length;
  if (versionCount == 0) {
    return 'Tag format must contain {version} exactly once: $format';
  }
  if (versionCount > 1) {
    return 'Tag format must contain {version} exactly once: $format';
  }

  final literalOnly =
      format.replaceAll(namePlaceholder, '').replaceAll(versionPlaceholder, '');
  if (invalidGitRefLiteralPattern.hasMatch(literalOnly)) {
    return 'Tag format contains invalid git ref characters: $format';
  }
  if (literalOnly.endsWith('.')) {
    return 'Tag format literal segment cannot end with ".": $format';
  }

  return null;
}

/// Substitutes `{name}` and `{version}` into [format].
String renderTagFormat({
  required String format,
  required String name,
  required String version,
}) {
  return format
      .replaceAll(namePlaceholder, name)
      .replaceAll(versionPlaceholder, version);
}

/// Builds a `git tag -l` glob from [format] with `{version}` replaced by `*`.
String tagGlobForFormat({
  required String format,
  required String name,
}) {
  return format
      .replaceAll(namePlaceholder, name)
      .replaceAll(versionPlaceholder, '*');
}

/// Parses the semver from [tag] using [format] and [name].
///
/// Returns `null` when [tag] does not match the full template.
Version? parseVersionFromTag({
  required String tag,
  required String format,
  required String name,
}) {
  final pattern = _tagFormatToRegExp(format: format, name: name);
  final match = pattern.firstMatch(tag);
  if (match == null) {
    return null;
  }

  final versionText = match.group(1);
  if (versionText == null || versionText.isEmpty) {
    return null;
  }

  try {
    return Version.parse(versionText);
  } on FormatException {
    return null;
  }
}

/// Lists release tags for [tagFormat] and returns the one with the highest
/// semver.
///
/// Non-matching tags and tags with unparseable versions are ignored.
({String? tag, Version? version, String? errorMessage}) resolveLatestTag({
  required Directory gitRoot,
  required String tagFormat,
  required String packageName,
}) {
  final formatError = validateTagFormat(tagFormat);
  if (formatError != null) {
    return (tag: null, version: null, errorMessage: formatError);
  }

  final glob = tagGlobForFormat(format: tagFormat, name: packageName);
  final result = Process.runSync(
    'git',
    ['-C', gitRoot.path, 'tag', '-l', glob],
  );
  if (result.exitCode != 0) {
    final stderrText = result.stderr.toString().trim();
    return (
      tag: null,
      version: null,
      errorMessage: stderrText.isEmpty
          ? 'Failed to list git tags matching "$glob".'
          : 'Failed to list git tags matching "$glob": $stderrText',
    );
  }

  String? latestTag;
  Version? latestVersion;

  for (final rawLine in result.stdout.toString().split('\n')) {
    final tag = rawLine.trim();
    if (tag.isEmpty) {
      continue;
    }

    final parsed = parseVersionFromTag(
      tag: tag,
      format: tagFormat,
      name: packageName,
    );
    if (parsed == null) {
      continue;
    }

    if (latestVersion == null || parsed > latestVersion) {
      latestTag = tag;
      latestVersion = parsed;
    }
  }

  return (tag: latestTag, version: latestVersion, errorMessage: null);
}

RegExp _tagFormatToRegExp({
  required String format,
  required String name,
}) {
  final buffer = StringBuffer('^');
  var index = 0;
  while (index < format.length) {
    if (format.startsWith(namePlaceholder, index)) {
      buffer.write(RegExp.escape(name));
      index += namePlaceholder.length;
      continue;
    }
    if (format.startsWith(versionPlaceholder, index)) {
      buffer.write(semverCapturePattern);
      index += versionPlaceholder.length;
      continue;
    }
    buffer.write(RegExp.escape(format[index]));
    index++;
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}
