import 'dart:io';

/// Resolves the git repository root containing [cwd].
///
/// Uses `git -C <cwd> rev-parse --show-toplevel`.
({Directory? gitRoot, String? errorMessage}) resolveGitRoot(Directory cwd) {
  final result = Process.runSync(
    'git',
    ['-C', cwd.path, 'rev-parse', '--show-toplevel'],
  );
  if (result.exitCode != 0) {
    final stderrText = result.stderr.toString().trim();
    if (stderrText.isNotEmpty) {
      return (
        gitRoot: null,
        errorMessage: 'Not a git repository: ${cwd.path} ($stderrText)',
      );
    }
    return (gitRoot: null, errorMessage: 'Not a git repository: ${cwd.path}');
  }

  final rootPath = result.stdout.toString().trim();
  if (rootPath.isEmpty) {
    return (
      gitRoot: null,
      errorMessage: 'Could not resolve git repository root for: ${cwd.path}',
    );
  }

  return (gitRoot: Directory(rootPath), errorMessage: null);
}

/// A git commit entry collected from `git log <tag>..HEAD`.
class GitCommitEntry {
  /// Creates a commit entry from [sha], [subject], and optional [body].
  const GitCommitEntry({
    required this.sha,
    required this.subject,
    this.body,
  });

  /// Full commit SHA.
  final String sha;

  /// First line of the commit message (subject).
  final String subject;

  /// Commit body after the subject, when present.
  final String? body;
}

/// Record delimiter used in custom `git log --format` output.
const gitCommitRecordDelimiter = '---COMMIT---';

/// Collects commits from `git log <latestTag>..HEAD`.
///
/// Returns entries in chronological order (oldest first).
({List<GitCommitEntry>? commits, String? errorMessage}) collectCommitsSinceTag({
  required Directory gitRoot,
  required String latestTag,
}) {
  final result = Process.runSync(
    'git',
    [
      '-C',
      gitRoot.path,
      'log',
      '$latestTag..HEAD',
      '--reverse',
      '--format=%H%n%s%n%b%n$gitCommitRecordDelimiter',
    ],
  );
  if (result.exitCode != 0) {
    final stderrText = result.stderr.toString().trim();
    return (
      commits: null,
      errorMessage: stderrText.isEmpty
          ? 'Failed to collect commits since tag $latestTag.'
          : 'Failed to collect commits since tag $latestTag: $stderrText',
    );
  }

  final stdoutText = result.stdout.toString();
  if (stdoutText.trim().isEmpty) {
    return (commits: const [], errorMessage: null);
  }

  final commits = <GitCommitEntry>[];
  for (final rawRecord in stdoutText.split('$gitCommitRecordDelimiter\n')) {
    final record = rawRecord.trim();
    if (record.isEmpty) {
      continue;
    }

    final lines = record.split('\n');
    if (lines.length < 2) {
      continue;
    }

    final sha = lines.first.trim();
    final subject = lines[1].trim();
    if (sha.isEmpty || subject.isEmpty) {
      continue;
    }

    final bodyLines = lines.skip(2).toList();
    while (bodyLines.isNotEmpty && bodyLines.last.trim().isEmpty) {
      bodyLines.removeLast();
    }
    final body = bodyLines.isEmpty ? null : bodyLines.join('\n');

    commits.add(GitCommitEntry(sha: sha, subject: subject, body: body));
  }

  return (commits: commits, errorMessage: null);
}
