import 'dart:io';

import 'package:args/args.dart';
import 'package:pub_semver/pub_semver.dart';

import 'lib/git.dart';
import 'lib/pubspec.dart';
import 'lib/tag_format.dart';

export 'lib/git.dart';
export 'lib/pubspec.dart';
export 'lib/tag_format.dart';

/// Package metadata and paths resolved from `--cwd`.
class PackageContext {
  const PackageContext({
    required this.name,
    required this.version,
    required this.packageCwd,
    required this.gitRoot,
    this.linkContext,
  });

  final String name;
  final String version;
  final Directory packageCwd;
  final Directory gitRoot;
  final ChangelogLinkContext? linkContext;
}

/// GitHub URLs used when formatting changelog issue and commit links.
class ChangelogLinkContext {
  const ChangelogLinkContext({
    this.issueBase,
    this.commitBase,
  });

  /// Base URL for issues, e.g. `https://github.com/owner/repo/issues`.
  final String? issueBase;

  /// Base URL for commits, e.g. `https://github.com/owner/repo/commit`.
  final String? commitBase;
}

/// Strips `/tree/...` path segments from a GitHub `repository:` URL.
///
/// Returns `null` when [repositoryUrl] is not a GitHub repository URL.
String? parseGitHubRepositoryBase(String repositoryUrl) {
  final uri = Uri.tryParse(repositoryUrl);
  if (uri == null || uri.host != 'github.com') {
    return null;
  }

  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.length < 2) {
    return null;
  }

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    path: '/${segments[0]}/${segments[1]}',
  ).toString();
}

/// Builds [ChangelogLinkContext] from pubspec `repository:` / `issue_tracker:`.
ChangelogLinkContext? buildChangelogLinkContext({
  String? repository,
  String? issueTracker,
}) {
  final repositoryBase =
      repository == null ? null : parseGitHubRepositoryBase(repository);

  final resolvedIssueBase = issueTracker ??
      (repositoryBase == null ? null : '$repositoryBase/issues');
  final resolvedCommitBase =
      repositoryBase == null ? null : '$repositoryBase/commit';

  if (resolvedIssueBase == null && resolvedCommitBase == null) {
    return null;
  }

  return ChangelogLinkContext(
    issueBase: resolvedIssueBase,
    commitBase: resolvedCommitBase,
  );
}

/// Resolves changelog link bases from [pubspecFile].
ChangelogLinkContext? readChangelogLinkContext(File pubspecFile) {
  final fields = readPubspecRepositoryFields(pubspecFile);
  return buildChangelogLinkContext(
    repository: fields.repository,
    issueTracker: fields.issueTracker,
  );
}

/// Resolves and validates package context from [cwdPath].
///
/// [cwdPath] is normalized to an absolute directory. Validation covers the
/// package directory, `pubspec.yaml`, `CHANGELOG.md`, and git work-tree
/// membership.
({PackageContext? context, String? errorMessage}) resolvePackageContext(
  String cwdPath,
) {
  final packageCwd = Directory(cwdPath).absolute;
  if (!packageCwd.existsSync()) {
    return (
      context: null,
      errorMessage: 'Package directory does not exist: ${packageCwd.path}',
    );
  }
  if (!FileSystemEntity.isDirectorySync(packageCwd.path)) {
    return (
      context: null,
      errorMessage: 'Package path is not a directory: ${packageCwd.path}',
    );
  }

  final pubspecFile = File('${packageCwd.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    return (
      context: null,
      errorMessage: 'Missing pubspec.yaml: ${pubspecFile.path}',
    );
  }

  final pubspecFields = readPubspecNameAndVersion(pubspecFile);
  if (pubspecFields.errorMessage != null) {
    return (context: null, errorMessage: pubspecFields.errorMessage);
  }

  final changelogFile = File('${packageCwd.path}/CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    return (
      context: null,
      errorMessage: 'Missing CHANGELOG.md: ${changelogFile.path}',
    );
  }

  final gitRootResult = resolveGitRoot(packageCwd);
  if (gitRootResult.errorMessage != null) {
    return (context: null, errorMessage: gitRootResult.errorMessage);
  }

  return (
    context: PackageContext(
      name: pubspecFields.name!,
      version: pubspecFields.version!,
      packageCwd: packageCwd,
      gitRoot: gitRootResult.gitRoot!,
      linkContext: readChangelogLinkContext(pubspecFile),
    ),
    errorMessage: null,
  );
}

/// Conventional commit types recognized by the prepare release tool.
const supportedConventionalCommitTypes = {
  'build',
  'chore',
  'ci',
  'docs',
  'feat',
  'fix',
  'perf',
  'refactor',
  'test',
};

final _conventionalCommitSubjectPattern = RegExp(
  r'^([a-zA-Z]+)(?:\(([^)]*)\))?(!)?: (.+)$',
);

/// A conventional commit parsed from a git subject line.
class ConventionalCommit {
  const ConventionalCommit({
    required this.type,
    required this.scopes,
    required this.description,
    required this.subject,
    required this.isBreakingChange,
    this.body,
    this.sha,
  });

  final String type;
  final List<String> scopes;
  final String description;
  final String subject;
  final bool isBreakingChange;
  final String? body;
  final String? sha;
}

/// Parses [subject] into a [ConventionalCommit].
///
/// Returns `null` when [subject] is not a conventional commit header.
ConventionalCommit? parseConventionalCommitSubject(String subject) {
  final trimmed = subject.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final match = _conventionalCommitSubjectPattern.firstMatch(trimmed);
  if (match == null) {
    return null;
  }

  final type = match.group(1)!.toLowerCase();
  final scopesRaw = match.group(2);
  final isBreakingChange = match.group(3) == '!';
  final description = match.group(4)!;
  if (description.isEmpty) {
    return null;
  }

  final scopes = scopesRaw == null || scopesRaw.isEmpty
      ? const <String>[]
      : scopesRaw
          .split(',')
          .map((scope) => scope.trim())
          .where((scope) => scope.isNotEmpty)
          .toList(growable: false);

  return ConventionalCommit(
    type: type,
    scopes: scopes,
    description: description,
    subject: trimmed,
    isBreakingChange: isBreakingChange,
  );
}

/// Parses a comma-separated `--commit-types` value.
///
/// Types are normalized to lowercase. Unknown type names produce error message.
({Set<String>? types, String? errorMessage}) parseCommitTypes(String input) {
  final segments = input
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) {
    return (
      types: null,
      errorMessage: 'Commit types list must not be empty.',
    );
  }

  final normalized = <String>{};
  final unknown = <String>[];

  for (final segment in segments) {
    final type = segment.toLowerCase();
    if (!supportedConventionalCommitTypes.contains(type)) {
      unknown.add(segment);
      continue;
    }
    normalized.add(type);
  }

  if (unknown.isNotEmpty) {
    return (
      types: null,
      errorMessage: 'Unknown commit type(s): ${unknown.join(', ')}',
    );
  }

  return (types: normalized, errorMessage: null);
}

/// Parses a comma-separated `--scopes` value.
({Set<String>? scopes, String? errorMessage}) parseScopes(String input) {
  final segments = input
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toSet();
  if (segments.isEmpty) {
    return (
      scopes: null,
      errorMessage: 'Scopes list must not be empty.',
    );
  }

  return (scopes: segments, errorMessage: null);
}

/// Returns commits from [subjects] whose scopes intersect [allowedScopes]
/// and whose type is in [allowedTypes].
///
/// Unscoped commits, wrong scopes, non-conventional subjects, and disallowed
/// types are excluded.
List<ConventionalCommit> filterConventionalCommits({
  required Iterable<String> subjects,
  required Set<String> allowedScopes,
  required Set<String> allowedTypes,
}) {
  final filtered = <ConventionalCommit>[];

  for (final subject in subjects) {
    final commit = parseConventionalCommitSubject(subject);
    if (commit == null) {
      continue;
    }
    if (commit.scopes.isEmpty || !commit.scopes.any(allowedScopes.contains)) {
      continue;
    }
    if (!allowedTypes.contains(commit.type)) {
      continue;
    }
    filtered.add(commit);
  }

  return filtered;
}

final _breakingChangeFooterPattern = RegExp(
  'BREAKING CHANGE:',
  caseSensitive: false,
);

/// Explicit semver bump segment for `--bump`.
enum ExplicitVersionBump {
  build,
  patch,
  minor,
  major,
}

/// Parses [versionText] as any valid semver version.
({Version? version, String? errorMessage}) parseSemverVersionText(
  String versionText,
) {
  final trimmed = versionText.trim();
  if (trimmed.isEmpty) {
    return (version: null, errorMessage: 'Version must not be empty.');
  }

  try {
    return (version: Version.parse(trimmed), errorMessage: null);
  } on FormatException {
    return (version: null, errorMessage: 'Invalid semver version: $trimmed');
  }
}

/// Parses a `--bump` CLI value into [ExplicitVersionBump].
({ExplicitVersionBump? bump, String? errorMessage}) parseExplicitVersionBump(
  String input,
) {
  switch (input.trim().toLowerCase()) {
    case 'build':
      return (bump: ExplicitVersionBump.build, errorMessage: null);
    case 'patch':
      return (bump: ExplicitVersionBump.patch, errorMessage: null);
    case 'minor':
      return (bump: ExplicitVersionBump.minor, errorMessage: null);
    case 'major':
      return (bump: ExplicitVersionBump.major, errorMessage: null);
    default:
      return (
        bump: null,
        errorMessage: 'Invalid --bump value: $input. '
            'Expected build, patch, minor, or major.',
      );
  }
}

String? _preReleaseString(Version version) {
  if (version.preRelease.isEmpty) {
    return null;
  }
  return version.preRelease.join('.');
}

/// Increments the `+N` build metadata on [current], preserving prerelease.
Version incrementBuildMetadata(Version current) {
  final existing = current.build;
  late final String nextBuild;
  if (existing.isEmpty) {
    nextBuild = '1';
  } else {
    final parts = existing.toList();
    final last = parts.last;
    final number = last is int ? last : int.tryParse('$last');
    if (number != null) {
      parts[parts.length - 1] = number + 1;
    } else {
      parts.add(1);
    }
    nextBuild = parts.join('.');
  }

  return Version(
    current.major,
    current.minor,
    current.patch,
    pre: _preReleaseString(current),
    build: nextBuild,
  );
}

/// Applies an explicit `--bump` override to [current].
///
/// Segment bumps (`patch`, `minor`, `major`) produce a stable version and
/// drop prerelease / build metadata. `build` increments `+N` only.
Version applyExplicitVersionBump({
  required Version current,
  required ExplicitVersionBump bump,
}) {
  switch (bump) {
    case ExplicitVersionBump.build:
      return incrementBuildMetadata(current);
    case ExplicitVersionBump.patch:
      return Version(current.major, current.minor, current.patch + 1);
    case ExplicitVersionBump.minor:
      return Version(current.major, current.minor + 1, 0);
    case ExplicitVersionBump.major:
      return Version(current.major + 1, 0, 0);
  }
}

/// Returns `true` when [commit] indicates a breaking change.
bool hasBreakingChange(ConventionalCommit commit) {
  if (commit.isBreakingChange) {
    return true;
  }
  final body = commit.body;
  if (body == null || body.isEmpty) {
    return false;
  }
  return _breakingChangeFooterPattern.hasMatch(body);
}

enum AutoBumpImpact {
  major,
  minor,
  patch,
  build,
}

/// Derives the highest semver impact from filtered [commits].
AutoBumpImpact determineAutoBumpImpact(List<ConventionalCommit> commits) {
  var hasBreakingFeat = false;
  var hasFeat = false;
  var hasFix = false;

  for (final commit in commits) {
    switch (commit.type) {
      case 'feat':
        if (hasBreakingChange(commit)) {
          hasBreakingFeat = true;
        } else {
          hasFeat = true;
        }
      case 'fix':
        hasFix = true;
      default:
        break;
    }
  }

  if (hasBreakingFeat) {
    return AutoBumpImpact.major;
  }
  if (hasFeat) {
    return AutoBumpImpact.minor;
  }
  if (hasFix) {
    return AutoBumpImpact.patch;
  }
  return AutoBumpImpact.build;
}

/// Applies auto bump rules from [commits] to [current].
///
/// In `0.x`, a breaking feat bumps minor (not major) to match coverde history.
Version applyAutoVersionBump({
  required Version current,
  required List<ConventionalCommit> commits,
}) {
  switch (determineAutoBumpImpact(commits)) {
    case AutoBumpImpact.major:
      if (current.major == 0) {
        return Version(0, current.minor + 1, 0);
      }
      return Version(current.major + 1, 0, 0);
    case AutoBumpImpact.minor:
      return Version(current.major, current.minor + 1, 0);
    case AutoBumpImpact.patch:
      return Version(current.major, current.minor, current.patch + 1);
    case AutoBumpImpact.build:
      return applyExplicitVersionBump(
        current: current,
        bump: ExplicitVersionBump.build,
      );
  }
}

/// Computes the next stable version from [currentVersion].
///
/// When [explicitBump] and [explicitVersionText] are both set, returns a
/// structured error. Auto mode requires at least one commit.
({Version? nextVersion, String? errorMessage}) computeNextVersion({
  required Version currentVersion,
  ExplicitVersionBump? explicitBump,
  String? explicitVersionText,
  List<ConventionalCommit> commits = const [],
}) {
  if (explicitBump != null && explicitVersionText != null) {
    return (
      nextVersion: null,
      errorMessage: '--bump and --version are mutually exclusive.',
    );
  }

  if (explicitVersionText != null) {
    final parsed = parseSemverVersionText(explicitVersionText);
    if (parsed.errorMessage != null) {
      return (nextVersion: null, errorMessage: parsed.errorMessage);
    }
    return (nextVersion: parsed.version, errorMessage: null);
  }

  if (explicitBump != null) {
    return (
      nextVersion: applyExplicitVersionBump(
        current: currentVersion,
        bump: explicitBump,
      ),
      errorMessage: null,
    );
  }

  if (commits.isEmpty) {
    return (
      nextVersion: null,
      errorMessage: 'No conventional commits available for auto version bump.',
    );
  }

  return (
    nextVersion: applyAutoVersionBump(
      current: currentVersion,
      commits: commits,
    ),
    errorMessage: null,
  );
}

/// Maps a conventional commit type to its changelog label.
String changelogTypeLabel(String type) {
  return type.toUpperCase();
}

final _commitShaMarkdownLinkPattern = RegExp(
  r'\(\[([0-9a-f]{7,40})\]\([^)]+\)\)',
  caseSensitive: false,
);

/// Bare `(#123)` references not already wrapped in markdown link syntax.
final _bareIssueReferencePattern = RegExp(r'(?<!\[)\(#(\d+)\)');

/// Replaces bare `(#NNN)` references with markdown issue links.
String linkifyIssueReferences({
  required String description,
  required String issueBase,
}) {
  return description.replaceAllMapped(_bareIssueReferencePattern, (match) {
    final issueNumber = match.group(1)!;
    return '([#$issueNumber]($issueBase/$issueNumber))';
  });
}

/// Formats a commit SHA as a markdown link using [commitBase].
String formatCommitShaMarkdownLink({
  required String fullSha,
  required String commitBase,
}) {
  final shortSha = fullSha.length >= 8 ? fullSha.substring(0, 8) : fullSha;
  return '([$shortSha]($commitBase/$fullSha))';
}

/// Extracts a commit SHA markdown link from [body] when present.
String? extractCommitShaMarkdownLink(String? body) {
  if (body == null || body.isEmpty) {
    return null;
  }

  final match = _commitShaMarkdownLinkPattern.firstMatch(body);
  if (match == null) {
    return null;
  }

  return match.group(0);
}

/// Formats a single changelog bullet for [commit].
///
/// Preserves issue/PR links present in the subject description. When commit
/// body contains a commit SHA markdown link, it is appended after the
/// description. Otherwise, [commit]\[ConventionalCommit.sha] is linked using
/// [linkContext].
String formatChangelogBullet(
  ConventionalCommit commit, {
  ChangelogLinkContext? linkContext,
}) {
  final label = changelogTypeLabel(commit.type);
  var description = commit.description.trim();
  final issueBase = linkContext?.issueBase;
  if (issueBase != null) {
    description = linkifyIssueReferences(
      description: description,
      issueBase: issueBase,
    );
  }

  final buffer = StringBuffer(' - **$label**: $description');

  final shaLink = extractCommitShaMarkdownLink(commit.body) ??
      _commitShaLinkFromGitSha(commit.sha, linkContext?.commitBase);
  if (shaLink != null && !description.contains(shaLink)) {
    if (!description.endsWith('.')) {
      buffer.write('.');
    }
    buffer.write(' $shaLink');
  } else if (!description.endsWith('.')) {
    buffer.write('.');
  }

  return buffer.toString();
}

String? _commitShaLinkFromGitSha(String? sha, String? commitBase) {
  if (sha == null || sha.isEmpty || commitBase == null) {
    return null;
  }

  return formatCommitShaMarkdownLink(fullSha: sha, commitBase: commitBase);
}

/// Builds a `## <version>` changelog section from [commits].
///
/// Returns a structured error when [commits] is empty.
({String? section, String? errorMessage}) buildChangelogSection({
  required String version,
  required List<ConventionalCommit> commits,
  String? latestTag,
  String? packageName,
  Set<String>? allowedTypes,
  ChangelogLinkContext? linkContext,
}) {
  if (commits.isEmpty) {
    final tagText = latestTag ?? '(none)';
    final nameText = packageName ?? '(unknown)';
    final typesText = allowedTypes == null || allowedTypes.isEmpty
        ? '(none)'
        : allowedTypes.join(', ');
    return (
      section: null,
      errorMessage: 'No commits matching scope and type filters since tag '
          '$tagText for package $nameText with allowed types: $typesText.',
    );
  }

  final lines = <String>[
    '## $version',
    '',
    for (final commit in commits)
      formatChangelogBullet(commit, linkContext: linkContext),
  ];

  return (section: lines.join('\n'), errorMessage: null);
}

/// Prepends [section] to [existingChangelog], preserving existing content.
String prependChangelogSection({
  required String existingChangelog,
  required String section,
}) {
  final trimmedExisting = existingChangelog.trimRight();
  if (trimmedExisting.isEmpty) {
    return '$section\n';
  }

  return '$section\n\n$trimmedExisting\n';
}

/// Builds a release changelog by prepending a new section for [version].
({String? changelog, String? section, String? errorMessage})
    buildReleaseChangelog({
  required String version,
  required String existingChangelog,
  required List<ConventionalCommit> commits,
  String? latestTag,
  String? packageName,
  Set<String>? allowedTypes,
  ChangelogLinkContext? linkContext,
}) {
  final sectionResult = buildChangelogSection(
    version: version,
    commits: commits,
    latestTag: latestTag,
    packageName: packageName,
    allowedTypes: allowedTypes,
    linkContext: linkContext,
  );
  if (sectionResult.errorMessage != null) {
    return (
      changelog: null,
      section: null,
      errorMessage: sectionResult.errorMessage,
    );
  }

  return (
    changelog: prependChangelogSection(
      existingChangelog: existingChangelog,
      section: sectionResult.section!,
    ),
    section: sectionResult.section,
    errorMessage: null,
  );
}

/// Why the release safety gate rejected a bump.
enum ReleaseSafetyFailure {
  noReleaseTag,
  pubspecAheadOfTag,
  pubspecBehindTag,
}

/// Validates the tag-based release safety gate.
///
/// When [allowUnsafeBump] is `true`, version mismatches are allowed but a
/// matching release tag must still exist.
({bool passed, ReleaseSafetyFailure? failure, String? errorMessage})
    checkReleaseSafetyGate({
  required Version currentVersion,
  required String? latestTag,
  required Version? latestTagVersion,
  required String tagFormat,
  required String packageName,
  bool allowUnsafeBump = false,
}) {
  final expectedTag = renderTagFormat(
    format: tagFormat,
    name: packageName,
    version: currentVersion.toString(),
  );

  if (latestTag == null || latestTagVersion == null) {
    return (
      passed: false,
      failure: ReleaseSafetyFailure.noReleaseTag,
      errorMessage: 'No release tag found for package $packageName. '
          'An existing release tag is required before preparing a new release. '
          'Expected tag for current version $currentVersion: $expectedTag.',
    );
  }

  if (allowUnsafeBump || currentVersion == latestTagVersion) {
    return (passed: true, failure: null, errorMessage: null);
  }

  if (currentVersion > latestTagVersion) {
    return (
      passed: false,
      failure: ReleaseSafetyFailure.pubspecAheadOfTag,
      errorMessage:
          'Package version $currentVersion is ahead of latest release '
              'tag $latestTag ($latestTagVersion). '
              'Expected tag for current version: $expectedTag.',
    );
  }

  return (
    passed: false,
    failure: ReleaseSafetyFailure.pubspecBehindTag,
    errorMessage:
        'Package version $currentVersion is behind latest release tag '
            '$latestTag ($latestTagVersion). Update pubspec version to match '
            'the latest tag or pass --allow-unsafe-bump for local recovery.',
  );
}

/// Resolves the latest release tag and validates the safety gate.
({String? latestTag, Version? latestTagVersion, String? errorMessage})
    resolveLatestTagWithSafetyGate({
  required Directory gitRoot,
  required String tagFormat,
  required String packageName,
  required Version currentVersion,
  bool allowUnsafeBump = false,
}) {
  final latestTagResult = resolveLatestTag(
    gitRoot: gitRoot,
    tagFormat: tagFormat,
    packageName: packageName,
  );
  if (latestTagResult.errorMessage != null) {
    return (
      latestTag: null,
      latestTagVersion: null,
      errorMessage: latestTagResult.errorMessage,
    );
  }

  final safetyResult = checkReleaseSafetyGate(
    currentVersion: currentVersion,
    latestTag: latestTagResult.tag,
    latestTagVersion: latestTagResult.version,
    tagFormat: tagFormat,
    packageName: packageName,
    allowUnsafeBump: allowUnsafeBump,
  );
  if (!safetyResult.passed) {
    return (
      latestTag: latestTagResult.tag,
      latestTagVersion: latestTagResult.version,
      errorMessage: safetyResult.errorMessage,
    );
  }

  return (
    latestTag: latestTagResult.tag,
    latestTagVersion: latestTagResult.version,
    errorMessage: null,
  );
}

/// Parses [entries] into conventional commits, preserving commit bodies.
List<ConventionalCommit> parseConventionalCommits(
  Iterable<GitCommitEntry> entries,
) {
  final commits = <ConventionalCommit>[];

  for (final entry in entries) {
    final parsed = parseConventionalCommitSubject(entry.subject);
    if (parsed == null) {
      continue;
    }

    commits.add(
      ConventionalCommit(
        type: parsed.type,
        scopes: parsed.scopes,
        description: parsed.description,
        subject: parsed.subject,
        isBreakingChange: parsed.isBreakingChange,
        body: entry.body,
        sha: entry.sha,
      ),
    );
  }

  return commits;
}

/// Collects scoped conventional commits since [latestTag].
({List<ConventionalCommit>? commits, String? errorMessage})
    collectScopedCommitsSinceTag({
  required Directory gitRoot,
  required String latestTag,
  required Set<String> allowedScopes,
  required Set<String> allowedTypes,
}) {
  final logResult = collectCommitsSinceTag(
    gitRoot: gitRoot,
    latestTag: latestTag,
  );
  if (logResult.errorMessage != null) {
    return (commits: null, errorMessage: logResult.errorMessage);
  }

  final parsed = parseConventionalCommits(logResult.commits!);
  final filtered = filterConventionalCommits(
    subjects: parsed.map((commit) => commit.subject),
    allowedScopes: allowedScopes,
    allowedTypes: allowedTypes,
  );
  final bodiesBySubject = {
    for (final commit in parsed) commit.subject: commit,
  };

  return (
    commits: [
      for (final commit in filtered)
        ConventionalCommit(
          type: commit.type,
          scopes: commit.scopes,
          description: commit.description,
          subject: commit.subject,
          isBreakingChange: commit.isBreakingChange,
          body: bodiesBySubject[commit.subject]?.body,
          sha: bodiesBySubject[commit.subject]?.sha,
        ),
    ],
    errorMessage: null,
  );
}

/// A dry-run or apply plan for preparing a package release.
class PrepareReleasePlan {
  const PrepareReleasePlan({
    required this.packageContext,
    required this.tagFormat,
    required this.allowedTypes,
    required this.latestTag,
    required this.currentVersion,
    required this.nextVersion,
    required this.commits,
    required this.changelogSection,
  });

  final PackageContext packageContext;
  final String tagFormat;
  final Set<String> allowedTypes;
  final String latestTag;
  final Version currentVersion;
  final Version nextVersion;
  final List<ConventionalCommit> commits;
  final String changelogSection;

  String get packageName => packageContext.name;

  String get suggestedCommitMessage =>
      'chore($packageName): release $nextVersion';
}

/// Builds a release plan from CLI inputs without writing files.
({PrepareReleasePlan? plan, String? errorMessage}) buildPrepareReleasePlan({
  required String cwd,
  required String tagFormat,
  required String commitTypesInput,
  String? scopesInput,
  bool allowUnsafeBump = false,
  ExplicitVersionBump? explicitBump,
  String? explicitVersionText,
}) {
  final contextResult = resolvePackageContext(cwd);
  if (contextResult.errorMessage != null) {
    return (plan: null, errorMessage: contextResult.errorMessage);
  }
  final packageContext = contextResult.context!;

  final formatError = validateTagFormat(tagFormat);
  if (formatError != null) {
    return (plan: null, errorMessage: formatError);
  }

  final commitTypesResult = parseCommitTypes(commitTypesInput);
  if (commitTypesResult.errorMessage != null) {
    return (plan: null, errorMessage: commitTypesResult.errorMessage);
  }
  final allowedTypes = commitTypesResult.types!;

  late final Set<String> allowedScopes;
  if (scopesInput == null || scopesInput.trim().isEmpty) {
    allowedScopes = {packageContext.name};
  } else {
    final scopesResult = parseScopes(scopesInput);
    if (scopesResult.errorMessage != null) {
      return (plan: null, errorMessage: scopesResult.errorMessage);
    }
    allowedScopes = scopesResult.scopes!;
  }

  final currentVersionResult = parseSemverVersionText(packageContext.version);
  if (currentVersionResult.errorMessage != null) {
    return (plan: null, errorMessage: currentVersionResult.errorMessage);
  }
  final currentVersion = currentVersionResult.version!;

  final safetyResult = resolveLatestTagWithSafetyGate(
    gitRoot: packageContext.gitRoot,
    tagFormat: tagFormat,
    packageName: packageContext.name,
    currentVersion: currentVersion,
    allowUnsafeBump: allowUnsafeBump,
  );
  if (safetyResult.errorMessage != null) {
    return (plan: null, errorMessage: safetyResult.errorMessage);
  }
  final latestTag = safetyResult.latestTag!;

  final commitsResult = collectScopedCommitsSinceTag(
    gitRoot: packageContext.gitRoot,
    latestTag: latestTag,
    allowedScopes: allowedScopes,
    allowedTypes: allowedTypes,
  );
  if (commitsResult.errorMessage != null) {
    return (plan: null, errorMessage: commitsResult.errorMessage);
  }
  final commits = commitsResult.commits!;

  final nextVersionResult = computeNextVersion(
    currentVersion: currentVersion,
    explicitBump: explicitBump,
    explicitVersionText: explicitVersionText,
    commits: commits,
  );
  if (nextVersionResult.errorMessage != null) {
    return (plan: null, errorMessage: nextVersionResult.errorMessage);
  }
  final nextVersion = nextVersionResult.nextVersion!;

  final changelogFile = File('${packageContext.packageCwd.path}/CHANGELOG.md');
  final existingChangelog = changelogFile.readAsStringSync();
  final changelogResult = buildReleaseChangelog(
    version: nextVersion.toString(),
    existingChangelog: existingChangelog,
    commits: commits,
    latestTag: latestTag,
    packageName: packageContext.name,
    allowedTypes: allowedTypes,
    linkContext: packageContext.linkContext,
  );
  if (changelogResult.errorMessage != null) {
    return (plan: null, errorMessage: changelogResult.errorMessage);
  }

  return (
    plan: PrepareReleasePlan(
      packageContext: packageContext,
      tagFormat: tagFormat,
      allowedTypes: allowedTypes,
      latestTag: latestTag,
      currentVersion: currentVersion,
      nextVersion: nextVersion,
      commits: commits,
      changelogSection: changelogResult.section!,
    ),
    errorMessage: null,
  );
}

/// Writes [plan] to `<cwd>/pubspec.yaml` and `<cwd>/CHANGELOG.md`.
///
/// Only the `version:` line in pubspec is changed. When the changelog write
/// fails, any pubspec update is rolled back.
({bool applied, String? errorMessage}) applyPrepareReleasePlan(
  PrepareReleasePlan plan,
) {
  final packageCwd = plan.packageContext.packageCwd;
  final pubspecFile = File('${packageCwd.path}/pubspec.yaml');
  final changelogFile = File('${packageCwd.path}/CHANGELOG.md');

  final originalPubspec = pubspecFile.readAsStringSync();
  final originalChangelog = changelogFile.readAsStringSync();
  final newVersionText = plan.nextVersion.toString();

  final pubspecUpdate = updatePubspecVersionLine(
    pubspecContents: originalPubspec,
    newVersion: newVersionText,
  );
  if (pubspecUpdate.errorMessage != null) {
    return (applied: false, errorMessage: pubspecUpdate.errorMessage);
  }

  final updatedChangelog = prependChangelogSection(
    existingChangelog: originalChangelog,
    section: plan.changelogSection,
  );

  try {
    pubspecFile.writeAsStringSync(pubspecUpdate.contents!);
  } on IOException catch (error) {
    return (
      applied: false,
      errorMessage: 'Failed to update pubspec.yaml: $error',
    );
  }

  try {
    changelogFile.writeAsStringSync(updatedChangelog);
  } on IOException catch (error) {
    try {
      pubspecFile.writeAsStringSync(originalPubspec);
    } on IOException {
      return (
        applied: false,
        errorMessage: 'Failed to update CHANGELOG.md: $error. '
            'pubspec.yaml was updated but could not be rolled back.',
      );
    }
    return (
      applied: false,
      errorMessage: 'Failed to update CHANGELOG.md: $error. '
          'pubspec.yaml was rolled back.',
    );
  }

  return (applied: true, errorMessage: null);
}

/// Prints a human-readable dry-run plan and machine-readable summary lines.
void printPrepareReleasePlan(PrepareReleasePlan plan) {
  stdout
    ..writeln(
      'Dry run — no files will be modified. Pass --apply to write '
      'pubspec.yaml and CHANGELOG.md.',
    )
    ..writeln()
    ..writeln('Package: ${plan.packageName}')
    ..writeln('Package directory: ${plan.packageContext.packageCwd.path}')
    ..writeln('Tag format: ${plan.tagFormat}')
    ..writeln('Current version: ${plan.currentVersion}')
    ..writeln('Latest release tag: ${plan.latestTag}')
    ..writeln('Next version: ${plan.nextVersion}')
    ..writeln('Allowed commit types: ${plan.allowedTypes.join(', ')}')
    ..writeln(
      'Matching commits since ${plan.latestTag}: ${plan.commits.length}',
    )
    ..writeln()
    ..writeln('Suggested commit message:')
    ..writeln(plan.suggestedCommitMessage)
    ..writeln()
    ..writeln('Files that would change:')
    ..writeln(
      '  pubspec.yaml (version: ${plan.currentVersion} → ${plan.nextVersion})',
    )
    ..writeln('  CHANGELOG.md (prepend new section)')
    ..writeln()
    ..writeln('Changelog preview:')
    ..writeln(plan.changelogSection)
    ..writeln()
    ..writeln('package_name=${plan.packageName}')
    ..writeln('release_version=${plan.nextVersion}')
    ..writeln('package_cwd=${plan.packageContext.packageCwd.path}')
    ..writeln('tag_format=${plan.tagFormat}')
    ..writeln('latest_tag=${plan.latestTag}');
}

/// Prints apply-mode summary after files were written.
void printApplyResult(PrepareReleasePlan plan) {
  stdout
    ..writeln('Applied release changes.')
    ..writeln()
    ..writeln('Package: ${plan.packageName}')
    ..writeln('Package directory: ${plan.packageContext.packageCwd.path}')
    ..writeln('Updated version: ${plan.currentVersion} → ${plan.nextVersion}')
    ..writeln('Prepended changelog section for ${plan.nextVersion}')
    ..writeln()
    ..writeln('Suggested commit message:')
    ..writeln(plan.suggestedCommitMessage)
    ..writeln()
    ..writeln('package_name=${plan.packageName}')
    ..writeln('release_version=${plan.nextVersion}')
    ..writeln('package_cwd=${plan.packageContext.packageCwd.path}')
    ..writeln('tag_format=${plan.tagFormat}')
    ..writeln('latest_tag=${plan.latestTag}');
}

ArgParser buildPrepareReleaseArgParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print usage information.',
    )
    ..addOption(
      'cwd',
      help: 'Package root directory '
          '(must contain pubspec.yaml and CHANGELOG.md).',
    )
    ..addOption(
      'tag-format',
      help:
          "Tag template with {name} and {version} ''(e.g. '{name}/{version}').",
    )
    ..addOption(
      'commit-types',
      help: 'Comma-separated conventional commit types '
          'to include in the changelog.',
    )
    ..addOption(
      'scopes',
      help: 'Comma-separated conventional commit scopes to include. '
          'Defaults to the package name from pubspec.yaml.',
    )
    ..addOption(
      'bump',
      help: 'Explicit semver bump (build, patch, minor, major). '
          'Mutually exclusive with --version.',
    )
    ..addOption(
      'version',
      help: 'Exact target semver version. '
          'Mutually exclusive with --bump.',
    )
    ..addFlag(
      'allow-unsafe-bump',
      help: 'Allow release planning when pubspec version does not match '
          'the latest release tag.',
    )
    ..addFlag(
      'apply',
      help: 'Write pubspec.yaml (version line only) and prepend CHANGELOG.md. '
          'Default is dry-run.',
    );
}

void printPrepareReleaseUsage() {
  stdout
    ..writeln('Usage: dart run tool/prepare_package_release.dart [options]')
    ..writeln()
    ..writeln(buildPrepareReleaseArgParser().usage);
}

/// Parses CLI arguments for the prepare release tool.
///
/// Returns `null` when usage is invalid; callers should exit `64`.
PrepareReleaseCliOptions? parsePrepareReleaseCliOptions(
  List<String> arguments,
) {
  if (arguments.isEmpty) {
    stderr.writeln('Missing required arguments.');
    return null;
  }

  if (arguments.contains('--help') || arguments.contains('-h')) {
    return const PrepareReleaseCliOptions(showHelp: true);
  }

  final parser = buildPrepareReleaseArgParser();
  try {
    final results = parser.parse(arguments);
    if (results['help'] == true) {
      return const PrepareReleaseCliOptions(showHelp: true);
    }

    final cwd = results['cwd'] as String?;
    if (cwd == null || cwd.isEmpty) {
      stderr.writeln('Missing value for --cwd');
      return null;
    }

    final tagFormat = results['tag-format'] as String?;
    if (tagFormat == null || tagFormat.isEmpty) {
      stderr.writeln('Missing value for --tag-format');
      return null;
    }

    final commitTypes = results['commit-types'] as String?;
    if (commitTypes == null || commitTypes.isEmpty) {
      stderr.writeln('Missing value for --commit-types');
      return null;
    }

    final bumpText = results['bump'] as String?;
    final versionText = results['version'] as String?;
    if (bumpText != null &&
        bumpText.isNotEmpty &&
        versionText != null &&
        versionText.isNotEmpty) {
      stderr.writeln('--bump and --version are mutually exclusive.');
      return null;
    }

    ExplicitVersionBump? explicitBump;
    if (bumpText != null && bumpText.isNotEmpty) {
      final bumpResult = parseExplicitVersionBump(bumpText);
      if (bumpResult.errorMessage != null) {
        stderr.writeln(bumpResult.errorMessage);
        return null;
      }
      explicitBump = bumpResult.bump;
    }

    final explicitVersionText =
        versionText != null && versionText.isNotEmpty ? versionText : null;

    final scopes = results['scopes'] as String?;

    return PrepareReleaseCliOptions(
      cwd: cwd,
      tagFormat: tagFormat,
      commitTypes: commitTypes,
      scopes: scopes != null && scopes.isNotEmpty ? scopes : null,
      explicitBump: explicitBump,
      explicitVersionText: explicitVersionText,
      allowUnsafeBump: results['allow-unsafe-bump'] as bool? ?? false,
      apply: results['apply'] as bool? ?? false,
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    return null;
  }
}

/// Parsed CLI options for [main].
class PrepareReleaseCliOptions {
  const PrepareReleaseCliOptions({
    this.showHelp = false,
    this.cwd,
    this.tagFormat,
    this.commitTypes,
    this.scopes,
    this.explicitBump,
    this.explicitVersionText,
    this.allowUnsafeBump = false,
    this.apply = false,
  });

  final bool showHelp;
  final String? cwd;
  final String? tagFormat;
  final String? commitTypes;
  final String? scopes;
  final ExplicitVersionBump? explicitBump;
  final String? explicitVersionText;
  final bool allowUnsafeBump;
  final bool apply;
}

void main(List<String> arguments) {
  final options = parsePrepareReleaseCliOptions(arguments);
  if (options == null) {
    printPrepareReleaseUsage();
    exit(64);
  }

  if (options.showHelp) {
    printPrepareReleaseUsage();
    exit(0);
  }

  final planResult = buildPrepareReleasePlan(
    cwd: options.cwd!,
    tagFormat: options.tagFormat!,
    commitTypesInput: options.commitTypes!,
    scopesInput: options.scopes,
    allowUnsafeBump: options.allowUnsafeBump,
    explicitBump: options.explicitBump,
    explicitVersionText: options.explicitVersionText,
  );
  if (planResult.errorMessage != null) {
    stderr.writeln(planResult.errorMessage);
    exit(1);
  }

  final plan = planResult.plan!;
  if (options.apply) {
    final applyResult = applyPrepareReleasePlan(plan);
    if (applyResult.errorMessage != null) {
      stderr.writeln(applyResult.errorMessage);
      exit(1);
    }
    printApplyResult(plan);
    exit(0);
  }

  printPrepareReleasePlan(plan);
  exit(0);
}
