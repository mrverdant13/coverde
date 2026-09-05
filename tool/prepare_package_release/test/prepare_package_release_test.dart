import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../prepare_package_release.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('coverde_prepare_release_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('readPubspecNameAndVersion', () {
    test('reads name and version from pubspec.yaml', () {
      final pubspecFile = _writePubspec(
        directory: tempRoot,
        name: 'synthetic_pkg',
        version: '1.2.3-dev.4',
      );

      final result = readPubspecNameAndVersion(pubspecFile);

      expect(result.errorMessage, isNull);
      expect(result.name, 'synthetic_pkg');
      expect(result.version, '1.2.3-dev.4');
    });

    test('fails when name is missing', () {
      final pubspecFile = File('${tempRoot.path}/pubspec.yaml')
        ..writeAsStringSync('version: 0.1.0\n');

      final result = readPubspecNameAndVersion(pubspecFile);

      expect(result.name, isNull);
      expect(result.version, isNull);
      expect(result.errorMessage, contains('Could not read name'));
    });

    test('fails when version is missing', () {
      final pubspecFile = File('${tempRoot.path}/pubspec.yaml')
        ..writeAsStringSync('name: synthetic_pkg\n');

      final result = readPubspecNameAndVersion(pubspecFile);

      expect(result.name, isNull);
      expect(result.version, isNull);
      expect(result.errorMessage, contains('Could not read version'));
    });
  });

  group('readPubspecRepositoryFields', () {
    test('reads repository and issue_tracker from pubspec.yaml', () {
      final pubspecFile = File('${tempRoot.path}/pubspec.yaml')
        ..writeAsStringSync('''
name: synthetic_pkg
version: 0.0.1-dev.1
repository: https://github.com/example/clay/tree/main/packages/synthetic_pkg
issue_tracker: https://github.com/example/clay/issues
''');

      final result = readPubspecRepositoryFields(pubspecFile);

      expect(
        result.repository,
        'https://github.com/example/clay/tree/main/packages/synthetic_pkg',
      );
      expect(result.issueTracker, 'https://github.com/example/clay/issues');
    });

    test('returns null fields when pubspec omits repository metadata', () {
      final pubspecFile = _writePubspec(
        directory: tempRoot,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );

      final result = readPubspecRepositoryFields(pubspecFile);

      expect(result.repository, isNull);
      expect(result.issueTracker, isNull);
    });
  });

  group('parseGitHubRepositoryBase', () {
    test('strips tree path segments from monorepo repository URLs', () {
      expect(
        parseGitHubRepositoryBase(
          'https://github.com/example/clay/tree/main/packages/synthetic_pkg',
        ),
        'https://github.com/example/clay',
      );
    });

    test('accepts repository root URLs', () {
      expect(
        parseGitHubRepositoryBase('https://github.com/example/clay'),
        'https://github.com/example/clay',
      );
    });

    test('returns null for non-GitHub URLs', () {
      expect(
        parseGitHubRepositoryBase('https://gitlab.com/example/clay'),
        isNull,
      );
    });
  });

  group('buildChangelogLinkContext', () {
    test('prefers issue_tracker and derives commit base from repository', () {
      final context = buildChangelogLinkContext(
        repository:
            'https://github.com/example/clay/tree/main/packages/synthetic_pkg',
        issueTracker: 'https://github.com/example/clay/issues',
      );

      expect(context, isNotNull);
      expect(context!.issueBase, 'https://github.com/example/clay/issues');
      expect(context.commitBase, 'https://github.com/example/clay/commit');
    });

    test('derives issue base from repository when issue_tracker is omitted',
        () {
      final context = buildChangelogLinkContext(
        repository: 'https://github.com/example/clay',
      );

      expect(context, isNotNull);
      expect(context!.issueBase, 'https://github.com/example/clay/issues');
      expect(context.commitBase, 'https://github.com/example/clay/commit');
    });

    test('returns null when no GitHub repository metadata is available', () {
      expect(buildChangelogLinkContext(), isNull);
      expect(
        buildChangelogLinkContext(
          repository: 'https://gitlab.com/example/clay',
        ),
        isNull,
      );
    });
  });

  group('resolveGitRoot', () {
    test('resolves git root for a package inside a repo', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );
      _gitCommitAll(tempRoot, message: 'init package');

      final result = resolveGitRoot(packageDir);

      expect(result.errorMessage, isNull);
      expect(
        Directory(result.gitRoot!.path).resolveSymbolicLinksSync(),
        Directory(tempRoot.absolute.path).resolveSymbolicLinksSync(),
      );
    });

    test('fails when cwd is outside a git work tree', () {
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );

      final result = resolveGitRoot(packageDir);

      expect(result.gitRoot, isNull);
      expect(result.errorMessage, contains('Not a git repository'));
    });
  });

  group('resolvePackageContext', () {
    test('resolves a valid package directory inside a git repo', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );
      _gitCommitAll(tempRoot, message: 'init package');

      final result = resolvePackageContext(packageDir.path);

      expect(result.errorMessage, isNull);
      final context = result.context!;
      expect(context.name, 'synthetic_pkg');
      expect(context.version, '0.0.1-dev.1');
      expect(context.packageCwd.path, packageDir.absolute.path);
      expect(
        Directory(context.gitRoot.path).resolveSymbolicLinksSync(),
        Directory(tempRoot.absolute.path).resolveSymbolicLinksSync(),
      );
      expect(context.linkContext, isNull);
    });

    test('resolves changelog link context from pubspec repository fields', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
        repository:
            'https://github.com/example/clay/tree/main/packages/synthetic_pkg',
        issueTracker: 'https://github.com/example/clay/issues',
      );
      _gitCommitAll(tempRoot, message: 'init package');

      final result = resolvePackageContext(packageDir.path);

      expect(result.errorMessage, isNull);
      final context = result.context!;
      expect(context.linkContext, isNotNull);
      expect(
        context.linkContext!.issueBase,
        'https://github.com/example/clay/issues',
      );
      expect(
        context.linkContext!.commitBase,
        'https://github.com/example/clay/commit',
      );
    });

    test('fails when package directory does not exist', () {
      final result = resolvePackageContext('${tempRoot.path}/missing');

      expect(result.context, isNull);
      expect(result.errorMessage, contains('does not exist'));
    });

    test('fails when pubspec.yaml is missing', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg')
        ..createSync(recursive: true);
      File('${packageDir.path}/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n');
      _gitCommitAll(tempRoot, message: 'init without pubspec');

      final result = resolvePackageContext(packageDir.path);

      expect(result.context, isNull);
      expect(result.errorMessage, contains('Missing pubspec.yaml'));
    });

    test('fails when CHANGELOG.md is missing', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePubspec(
        directory: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );
      _gitCommitAll(tempRoot, message: 'init without changelog');

      final result = resolvePackageContext(packageDir.path);

      expect(result.context, isNull);
      expect(result.errorMessage, contains('Missing CHANGELOG.md'));
    });

    test('fails when pubspec name is missing', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg')
        ..createSync(recursive: true);
      File('${packageDir.path}/pubspec.yaml').writeAsStringSync(
        'version: 0.0.1-dev.1\n',
      );
      File('${packageDir.path}/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n');
      _gitCommitAll(tempRoot, message: 'invalid pubspec');

      final result = resolvePackageContext(packageDir.path);

      expect(result.context, isNull);
      expect(result.errorMessage, contains('Could not read name'));
    });

    test('fails when pubspec version is missing', () {
      _initGitRepo(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg')
        ..createSync(recursive: true);
      File('${packageDir.path}/pubspec.yaml').writeAsStringSync(
        'name: synthetic_pkg\n',
      );
      File('${packageDir.path}/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n');
      _gitCommitAll(tempRoot, message: 'invalid pubspec');

      final result = resolvePackageContext(packageDir.path);

      expect(result.context, isNull);
      expect(result.errorMessage, contains('Could not read version'));
    });

    test('fails when package directory is not inside a git repo', () {
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.1',
      );

      final result = resolvePackageContext(packageDir.path);

      expect(result.context, isNull);
      expect(result.errorMessage, contains('Not a git repository'));
    });
  });

  group('validateTagFormat', () {
    test('accepts clay monorepo format', () {
      expect(validateTagFormat('{name}/{version}'), isNull);
    });

    test('accepts single-package format', () {
      expect(validateTagFormat('v{version}'), isNull);
    });

    test('rejects template without version placeholder', () {
      expect(
        validateTagFormat('{name}/release'),
        contains('{version} exactly once'),
      );
    });

    test('rejects template with multiple version placeholders', () {
      expect(
        validateTagFormat('v{version}-{version}'),
        contains('{version} exactly once'),
      );
    });

    test('rejects invalid git ref literal characters', () {
      expect(
        validateTagFormat('release?{version}'),
        contains('invalid git ref characters'),
      );
    });
  });

  group('renderTagFormat', () {
    test('renders clay monorepo tag', () {
      expect(
        renderTagFormat(
          format: '{name}/{version}',
          name: 'clay_core',
          version: '0.0.1-dev.2',
        ),
        'clay_core/0.0.1-dev.2',
      );
    });

    test('renders single-package tag', () {
      expect(
        renderTagFormat(
          format: 'v{version}',
          name: 'ignored',
          version: '1.0.0',
        ),
        'v1.0.0',
      );
    });
  });

  group('tagGlobForFormat', () {
    test('builds clay monorepo glob', () {
      expect(
        tagGlobForFormat(format: '{name}/{version}', name: 'clay_core'),
        'clay_core/*',
      );
    });

    test('builds single-package glob', () {
      expect(
        tagGlobForFormat(format: 'v{version}', name: 'ignored'),
        'v*',
      );
    });
  });

  group('parseVersionFromTag', () {
    test('parses clay monorepo tag', () {
      expect(
        parseVersionFromTag(
          tag: 'clay_core/0.0.1-dev.2',
          format: '{name}/{version}',
          name: 'clay_core',
        ),
        Version.parse('0.0.1-dev.2'),
      );
    });

    test('parses single-package tag', () {
      expect(
        parseVersionFromTag(
          tag: 'v1.0.0',
          format: 'v{version}',
          name: 'my_pkg',
        ),
        Version.parse('1.0.0'),
      );
    });

    test('ignores tags that do not match the full template', () {
      expect(
        parseVersionFromTag(
          tag: 'clay_core/extra/0.0.1-dev.2',
          format: '{name}/{version}',
          name: 'clay_core',
        ),
        isNull,
      );
      expect(
        parseVersionFromTag(
          tag: 'clay_cli/0.0.1-dev.2',
          format: '{name}/{version}',
          name: 'clay_core',
        ),
        isNull,
      );
      expect(
        parseVersionFromTag(
          tag: 'v1.0.0-beta',
          format: 'v{version}',
          name: 'my_pkg',
        ),
        Version.parse('1.0.0-beta'),
      );
    });

    test('ignores tags with unparseable version segments', () {
      expect(
        parseVersionFromTag(
          tag: 'clay_core/not-a-version',
          format: '{name}/{version}',
          name: 'clay_core',
        ),
        isNull,
      );
    });
  });

  group('resolveLatestTag', () {
    test('returns highest semver among matching annotated tags', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'clay_core/0.0.1-dev.1');
      _gitCreateAnnotatedTag(tempRoot, 'clay_core/0.0.1-dev.3');
      _gitCreateAnnotatedTag(tempRoot, 'clay_core/0.0.1-dev.2');
      _gitCreateAnnotatedTag(tempRoot, 'clay_cli/0.0.1-dev.9');
      _gitCreateAnnotatedTag(tempRoot, 'clay_core/not-a-version');
      _gitCreateAnnotatedTag(tempRoot, 'clay_core/0.0.1-dev.2-extra');

      final result = resolveLatestTag(
        gitRoot: tempRoot,
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.errorMessage, isNull);
      expect(result.tag, 'clay_core/0.0.1-dev.3');
      expect(result.version, Version.parse('0.0.1-dev.3'));
    });

    test('supports single-package tag format', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'v0.9.0');
      _gitCreateAnnotatedTag(tempRoot, 'v1.0.0');

      final result = resolveLatestTag(
        gitRoot: tempRoot,
        tagFormat: 'v{version}',
        packageName: 'my_pkg',
      );

      expect(result.errorMessage, isNull);
      expect(result.tag, 'v1.0.0');
      expect(result.version, Version.parse('1.0.0'));
    });

    test('returns null tag when no matching tags exist', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'clay_cli/0.0.1-dev.1');

      final result = resolveLatestTag(
        gitRoot: tempRoot,
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.errorMessage, isNull);
      expect(result.tag, isNull);
      expect(result.version, isNull);
    });

    test('rejects invalid tag format', () {
      _initGitRepo(tempRoot);

      final result = resolveLatestTag(
        gitRoot: tempRoot,
        tagFormat: 'release',
        packageName: 'clay_core',
      );

      expect(result.tag, isNull);
      expect(result.version, isNull);
      expect(result.errorMessage, contains('{version} exactly once'));
    });
  });

  group('parseConventionalCommitSubject', () {
    test('parses scoped commit with single scope', () {
      final commit = parseConventionalCommitSubject(
        'fix(clay_cli): resolve relative paths from project root',
      );

      expect(commit, isNotNull);
      expect(commit!.type, 'fix');
      expect(commit.scopes, ['clay_cli']);
      expect(
        commit.description,
        'resolve relative paths from project root',
      );
      expect(commit.isBreakingChange, isFalse);
    });

    test('parses scoped commit with multiple scopes', () {
      final commit = parseConventionalCommitSubject(
        'feat(clay_cli,clay_vsc_extension): wire preview command',
      );

      expect(commit, isNotNull);
      expect(commit!.type, 'feat');
      expect(commit.scopes, ['clay_cli', 'clay_vsc_extension']);
      expect(commit.description, 'wire preview command');
    });

    test('parses breaking change indicator in header', () {
      final commit = parseConventionalCommitSubject(
        'feat(clay_cli)!: drop legacy preview flag',
      );

      expect(commit, isNotNull);
      expect(commit!.type, 'feat');
      expect(commit.scopes, ['clay_cli']);
      expect(commit.isBreakingChange, isTrue);
    });

    test('normalizes commit type to lowercase', () {
      final commit = parseConventionalCommitSubject(
        'FEAT(clay_cli): add preview command',
      );

      expect(commit, isNotNull);
      expect(commit!.type, 'feat');
    });

    test('parses unscoped conventional commit without scopes', () {
      final commit =
          parseConventionalCommitSubject('chore: update CI workflow');

      expect(commit, isNotNull);
      expect(commit!.type, 'chore');
      expect(commit.scopes, isEmpty);
    });

    test('returns null for non-conventional subject', () {
      expect(
        parseConventionalCommitSubject(
          'Merge pull request #99 from example/feature-branch',
        ),
        isNull,
      );
      expect(parseConventionalCommitSubject('WIP preview work'), isNull);
    });

    test('returns null when description is missing', () {
      expect(parseConventionalCommitSubject('feat(clay_cli):'), isNull);
    });
  });

  group('parseCommitTypes', () {
    test('parses workflow default commit types', () {
      final result = parseCommitTypes('feat,fix,docs,refactor,test,build');

      expect(result.errorMessage, isNull);
      expect(
        result.types,
        {
          'feat',
          'fix',
          'docs',
          'refactor',
          'test',
          'build',
        },
      );
    });

    test('normalizes commit types case-insensitively', () {
      final result = parseCommitTypes('FEAT,Fix,DOCS');

      expect(result.errorMessage, isNull);
      expect(result.types, {'feat', 'fix', 'docs'});
    });

    test('deduplicates repeated commit types', () {
      final result = parseCommitTypes('feat,feat,fix');

      expect(result.errorMessage, isNull);
      expect(result.types, {'feat', 'fix'});
    });

    test('rejects empty commit types list', () {
      final result = parseCommitTypes('   ');

      expect(result.types, isNull);
      expect(result.errorMessage, contains('must not be empty'));
    });

    test('rejects unknown commit types', () {
      final result = parseCommitTypes('feat,unknown,fix');

      expect(result.types, isNull);
      expect(result.errorMessage, contains('Unknown commit type(s): unknown'));
    });

    test('accepts perf as a commit type', () {
      final result = parseCommitTypes('feat,perf,fix');

      expect(result.errorMessage, isNull);
      expect(result.types, contains('perf'));
    });
  });

  group('parseScopes', () {
    test('parses a comma-separated scope list', () {
      final result = parseScopes('coverde-cli, coverde');

      expect(result.errorMessage, isNull);
      expect(result.scopes, {'coverde-cli', 'coverde'});
    });

    test('rejects an empty scopes list', () {
      final result = parseScopes('   ');

      expect(result.scopes, isNull);
      expect(result.errorMessage, contains('must not be empty'));
    });
  });

  group('filterConventionalCommits', () {
    test('includes multi-scope commits when package name matches', () {
      final filtered = filterConventionalCommits(
        subjects: const [
          'feat(clay_cli,clay_vsc_extension): add preview',
          'feat(clay_core): add validation',
        ],
        allowedScopes: {'clay_cli'},
        allowedTypes: const {'feat', 'fix'},
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.type, 'feat');
      expect(filtered.single.scopes, ['clay_cli', 'clay_vsc_extension']);
    });

    test('matches an explicit scope that differs from the package name', () {
      final filtered = filterConventionalCommits(
        subjects: const [
          'feat(coverde-cli): add transform command',
          'feat(coverde): ignored pub name scope',
        ],
        allowedScopes: {'coverde-cli'},
        allowedTypes: const {'feat', 'fix'},
      );

      expect(filtered, hasLength(1));
      expect(
        filtered.single.subject,
        'feat(coverde-cli): add transform command',
      );
    });

    test('excludes unscoped and wrong-scope commits', () {
      final filtered = filterConventionalCommits(
        subjects: const [
          'chore: update CI',
          'feat(clay_core): add validation',
          'fix(clay_cli): resolve paths',
        ],
        allowedScopes: {'clay_cli'},
        allowedTypes: const {
          'feat',
          'fix',
          'docs',
          'refactor',
          'test',
          'build',
        },
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.subject, 'fix(clay_cli): resolve paths');
    });

    test('excludes commits whose type is not allowed', () {
      final filtered = filterConventionalCommits(
        subjects: const [
          'chore(clay_cli): release 0.0.1-dev.2',
          'feat(clay_cli): add preview',
        ],
        allowedScopes: {'clay_cli'},
        allowedTypes: const {
          'feat',
          'fix',
          'docs',
          'refactor',
          'test',
          'build',
        },
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.type, 'feat');
    });

    test('matches fixture subjects from anonymized history', () {
      final fixtureFile = _readTestFixture('commit_subjects.json');
      final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
      final packageName = fixture['packageName'] as String;
      final allowedTypes =
          (fixture['allowedTypes'] as List).cast<String>().toSet();
      final subjects = (fixture['subjects'] as List)
          .cast<Map<Object?, Object?>>()
          .map((entry) => entry['subject']! as String)
          .toList();

      final filtered = filterConventionalCommits(
        subjects: subjects,
        allowedScopes: {packageName},
        allowedTypes: allowedTypes,
      );
      final includedSubjects = filtered.map((commit) => commit.subject).toSet();

      for (final entry in fixture['subjects'] as List) {
        final subject = (entry as Map)['subject'] as String;
        final included = entry['included'] as bool;
        expect(
          includedSubjects.contains(subject),
          included,
          reason: subject,
        );
      }
    });
  });

  group('parseSemverVersionText', () {
    test('parses stable, build, and prerelease versions', () {
      expect(
        parseSemverVersionText('0.4.1').version,
        Version.parse('0.4.1'),
      );
      expect(
        parseSemverVersionText('0.4.1+1').version,
        Version.parse('0.4.1+1'),
      );
      expect(
        parseSemverVersionText('0.0.1-dev.99').version,
        Version.parse('0.0.1-dev.99'),
      );
    });

    test('rejects invalid semver', () {
      final result = parseSemverVersionText('not-a-version');

      expect(result.version, isNull);
      expect(result.errorMessage, contains('Invalid semver'));
    });
  });

  group('hasBreakingChange', () {
    test('detects breaking indicator in header', () {
      const commit = ConventionalCommit(
        type: 'feat',
        scopes: ['clay_cli'],
        description: 'drop legacy flag',
        subject: 'feat(clay_cli)!: drop legacy flag',
        isBreakingChange: true,
      );

      expect(hasBreakingChange(commit), isTrue);
    });

    test('detects BREAKING CHANGE footer in body', () {
      const commit = ConventionalCommit(
        type: 'feat',
        scopes: ['clay_cli'],
        description: 'reshape preview API',
        subject: 'feat(clay_cli): reshape preview API',
        isBreakingChange: false,
        body: 'BREAKING CHANGE: preview command flags were renamed.',
      );

      expect(hasBreakingChange(commit), isTrue);
    });
  });

  group('parseExplicitVersionBump', () {
    test('parses supported bump values case-insensitively', () {
      expect(
        parseExplicitVersionBump('build').bump,
        ExplicitVersionBump.build,
      );
      expect(
        parseExplicitVersionBump('PATCH').bump,
        ExplicitVersionBump.patch,
      );
      expect(
        parseExplicitVersionBump('Minor').bump,
        ExplicitVersionBump.minor,
      );
      expect(
        parseExplicitVersionBump('major').bump,
        ExplicitVersionBump.major,
      );
    });

    test('rejects unknown bump values', () {
      final result = parseExplicitVersionBump('invalid');

      expect(result.bump, isNull);
      expect(result.errorMessage, contains('Invalid --bump value'));
    });
  });

  group('applyExplicitVersionBump', () {
    final current = Version.parse('0.4.1');

    test('build increments +N metadata', () {
      expect(
        applyExplicitVersionBump(
          current: current,
          bump: ExplicitVersionBump.build,
        ),
        Version.parse('0.4.1+1'),
      );
      expect(
        applyExplicitVersionBump(
          current: Version.parse('0.4.1+1'),
          bump: ExplicitVersionBump.build,
        ),
        Version.parse('0.4.1+2'),
      );
    });

    test('patch increments patch and drops metadata', () {
      expect(
        applyExplicitVersionBump(
          current: current,
          bump: ExplicitVersionBump.patch,
        ),
        Version.parse('0.4.2'),
      );
    });

    test('minor increments minor', () {
      expect(
        applyExplicitVersionBump(
          current: current,
          bump: ExplicitVersionBump.minor,
        ),
        Version.parse('0.5.0'),
      );
    });

    test('major increments major', () {
      expect(
        applyExplicitVersionBump(
          current: current,
          bump: ExplicitVersionBump.major,
        ),
        Version.parse('1.0.0'),
      );
    });
  });

  group('applyAutoVersionBump', () {
    ConventionalCommit commitFromMap(Map<Object?, Object?> entry) {
      return ConventionalCommit(
        type: entry['type']! as String,
        scopes: (entry['scopes']! as List).cast<String>(),
        description: entry['description']! as String,
        subject: entry['subject']! as String,
        isBreakingChange: entry['isBreakingChange'] as bool? ?? false,
        body: entry['body'] as String?,
      );
    }

    test('matches fixture auto bump cases', () {
      final fixtureFile = _readTestFixture('version_bump_cases.json');
      final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
      final currentVersion = Version.parse(fixture['currentVersion'] as String);

      for (final rawCase in fixture['cases'] as List) {
        final testCase = rawCase as Map;
        final commits = (testCase['commits'] as List)
            .cast<Map<Object?, Object?>>()
            .map(commitFromMap)
            .toList();
        final expected = Version.parse(testCase['expectedVersion'] as String);

        expect(
          applyAutoVersionBump(current: currentVersion, commits: commits),
          expected,
          reason: testCase['name'] as String,
        );
      }
    });

    test('1.x breaking feat increments major', () {
      expect(
        applyAutoVersionBump(
          current: Version.parse('1.2.3'),
          commits: const [
            ConventionalCommit(
              type: 'feat',
              scopes: ['coverde-cli'],
              description: 'drop legacy flag',
              subject: 'feat(coverde-cli)!: drop legacy flag',
              isBreakingChange: true,
            ),
          ],
        ),
        Version.parse('2.0.0'),
      );
    });
  });

  group('computeNextVersion', () {
    final current = Version.parse('0.4.1');

    test('auto mode bumps from commits', () {
      final result = computeNextVersion(
        currentVersion: current,
        commits: [
          const ConventionalCommit(
            type: 'fix',
            scopes: ['coverde-cli'],
            description: 'resolve paths',
            subject: 'fix(coverde-cli): resolve paths',
            isBreakingChange: false,
          ),
        ],
      );

      expect(result.errorMessage, isNull);
      expect(result.nextVersion, Version.parse('0.4.2'));
    });

    test('explicit bump override ignores commits', () {
      final result = computeNextVersion(
        currentVersion: current,
        explicitBump: ExplicitVersionBump.minor,
        commits: [
          const ConventionalCommit(
            type: 'fix',
            scopes: ['coverde-cli'],
            description: 'resolve paths',
            subject: 'fix(coverde-cli): resolve paths',
            isBreakingChange: false,
          ),
        ],
      );

      expect(result.errorMessage, isNull);
      expect(result.nextVersion, Version.parse('0.5.0'));
    });

    test('explicit version override sets exact target', () {
      final result = computeNextVersion(
        currentVersion: current,
        explicitVersionText: '0.0.1-dev.99',
      );

      expect(result.errorMessage, isNull);
      expect(result.nextVersion, Version.parse('0.0.1-dev.99'));
    });

    test('rejects mutually exclusive bump and version overrides', () {
      final result = computeNextVersion(
        currentVersion: current,
        explicitBump: ExplicitVersionBump.patch,
        explicitVersionText: '0.0.1-dev.99',
      );

      expect(result.nextVersion, isNull);
      expect(result.errorMessage, contains('mutually exclusive'));
    });

    test('rejects auto mode without commits', () {
      final result = computeNextVersion(currentVersion: current);

      expect(result.nextVersion, isNull);
      expect(result.errorMessage, contains('No conventional commits'));
    });

    test('accepts a 1.x current version for explicit major', () {
      final result = computeNextVersion(
        currentVersion: Version.parse('1.2.3'),
        explicitBump: ExplicitVersionBump.major,
      );

      expect(result.errorMessage, isNull);
      expect(result.nextVersion, Version.parse('2.0.0'));
    });
  });

  group('changelogTypeLabel', () {
    test('maps conventional types to uppercase labels', () {
      expect(changelogTypeLabel('feat'), 'FEAT');
      expect(changelogTypeLabel('fix'), 'FIX');
      expect(changelogTypeLabel('docs'), 'DOCS');
      expect(changelogTypeLabel('refactor'), 'REFACTOR');
      expect(changelogTypeLabel('test'), 'TEST');
      expect(changelogTypeLabel('chore'), 'CHORE');
      expect(changelogTypeLabel('ci'), 'CI');
      expect(changelogTypeLabel('build'), 'BUILD');
      expect(changelogTypeLabel('perf'), 'PERF');
    });
  });

  group('linkifyIssueReferences', () {
    test('wraps bare issue references in markdown links', () {
      expect(
        linkifyIssueReferences(
          description: 'handle missing config (#43)',
          issueBase: 'https://github.com/example/clay/issues',
        ),
        'handle missing config ([#43](https://github.com/example/clay/issues/43))',
      );
    });

    test('leaves existing markdown issue links unchanged', () {
      const description =
          'add preview command ([#42](https://github.com/example/clay/issues/42))';

      expect(
        linkifyIssueReferences(
          description: description,
          issueBase: 'https://github.com/example/clay/issues',
        ),
        description,
      );
    });
  });

  group('formatCommitShaMarkdownLink', () {
    test('uses an eight-character short SHA in the link label', () {
      expect(
        formatCommitShaMarkdownLink(
          fullSha: 'abc1234def5678901234567890abcdef12345678',
          commitBase: 'https://github.com/example/clay/commit',
        ),
        '([abc1234d](https://github.com/example/clay/commit/abc1234def5678901234567890abcdef12345678))',
      );
    });
  });

  group('formatChangelogBullet', () {
    test('preserves issue links from the subject and appends sha links', () {
      const commit = ConventionalCommit(
        type: 'feat',
        scopes: ['synthetic_pkg'],
        description:
            'add preview command ([#42](https://github.com/example/clay/issues/42))',
        subject:
            'feat(synthetic_pkg): add preview command ([#42](https://github.com/example/clay/issues/42))',
        isBreakingChange: false,
        body:
            '([abc1234](https://github.com/example/clay/commit/abc1234def5678901234567890abcdef12345678))',
      );

      expect(
        formatChangelogBullet(commit),
        ' - **FEAT**: add preview command ([#42](https://github.com/example/clay/issues/42)). ([abc1234](https://github.com/example/clay/commit/abc1234def5678901234567890abcdef12345678))',
      );
    });

    test('linkifies bare issue refs and git SHAs when link context is set', () {
      const linkContext = ChangelogLinkContext(
        issueBase: 'https://github.com/example/clay/issues',
        commitBase: 'https://github.com/example/clay/commit',
      );
      const commit = ConventionalCommit(
        type: 'fix',
        scopes: ['synthetic_pkg'],
        description: 'handle missing config (#43)',
        subject: 'fix(synthetic_pkg): handle missing config (#43)',
        isBreakingChange: false,
        sha: 'def56789abcdef0123456789abcdef0123456789',
      );

      expect(
        formatChangelogBullet(commit, linkContext: linkContext),
        ' - **FIX**: handle missing config ([#43](https://github.com/example/clay/issues/43)). ([def56789](https://github.com/example/clay/commit/def56789abcdef0123456789abcdef0123456789))',
      );
    });

    test('adds trailing period for plain descriptions', () {
      const commit = ConventionalCommit(
        type: 'docs',
        scopes: ['synthetic_pkg'],
        description: 'document marker syntax with examples',
        subject: 'docs(synthetic_pkg): document marker syntax with examples',
        isBreakingChange: false,
      );

      expect(
        formatChangelogBullet(commit),
        ' - **DOCS**: document marker syntax with examples.',
      );
    });

    test('preserves shorthand issue references without link context', () {
      const commit = ConventionalCommit(
        type: 'fix',
        scopes: ['synthetic_pkg'],
        description: 'handle missing config (#43)',
        subject: 'fix(synthetic_pkg): handle missing config (#43)',
        isBreakingChange: false,
      );

      expect(
        formatChangelogBullet(commit),
        ' - **FIX**: handle missing config (#43).',
      );
    });
  });

  group('buildChangelogSection', () {
    test('returns structured error when commit list is empty', () {
      final result = buildChangelogSection(
        version: '0.0.1-dev.3',
        commits: const [],
        latestTag: 'synthetic_pkg/0.0.1-dev.2',
        packageName: 'synthetic_pkg',
        allowedTypes: const {'feat', 'fix'},
      );

      expect(result.section, isNull);
      expect(
        result.errorMessage,
        'No commits matching scope and type filters since tag '
        'synthetic_pkg/0.0.1-dev.2 for package synthetic_pkg with allowed '
        'types: feat, fix.',
      );
    });
  });

  group('prependChangelogSection', () {
    test('prepends a new section while preserving existing content', () {
      const existing = '## 0.0.1-dev.2\n\n - **FEAT**: previous entry.\n';
      const section =
          '## 0.0.1-dev.3\n\n - **FIX**: handle missing config (#43).';

      expect(
        prependChangelogSection(
          existingChangelog: existing,
          section: section,
        ),
        '## 0.0.1-dev.3\n\n - **FIX**: handle missing config (#43).\n\n'
        '## 0.0.1-dev.2\n\n - **FEAT**: previous entry.\n',
      );
    });
  });

  group('buildReleaseChangelog', () {
    ConventionalCommit commitFromMap(Map<Object?, Object?> entry) {
      return ConventionalCommit(
        type: entry['type']! as String,
        scopes: (entry['scopes']! as List).cast<String>(),
        description: entry['description']! as String,
        subject: entry['subject']! as String,
        isBreakingChange: entry['isBreakingChange'] as bool? ?? false,
        body: entry['body'] as String?,
        sha: entry['sha'] as String?,
      );
    }

    ChangelogLinkContext? linkContextFromFixture(
      Map<Object?, Object?> fixture,
    ) {
      final linkContext = fixture['linkContext'] as Map?;
      if (linkContext == null) {
        return null;
      }

      return ChangelogLinkContext(
        issueBase: linkContext['issueBase'] as String?,
        commitBase: linkContext['commitBase'] as String?,
      );
    }

    test('matches golden fixture output', () {
      final fixtureFile = _readTestFixture('changelog_builder_cases.json');
      final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
      final commits = (fixture['commits'] as List)
          .cast<Map<Object?, Object?>>()
          .map(commitFromMap)
          .toList();

      final linkContext = linkContextFromFixture(fixture);

      final sectionResult = buildChangelogSection(
        version: fixture['version'] as String,
        commits: commits,
        latestTag: fixture['latestTag'] as String,
        packageName: fixture['packageName'] as String,
        allowedTypes: (fixture['allowedTypes'] as List).cast<String>().toSet(),
        linkContext: linkContext,
      );

      expect(sectionResult.errorMessage, isNull);
      expect(sectionResult.section, fixture['expectedSection']);

      final changelogResult = buildReleaseChangelog(
        version: fixture['version'] as String,
        existingChangelog: fixture['existingChangelog'] as String,
        commits: commits,
        latestTag: fixture['latestTag'] as String,
        packageName: fixture['packageName'] as String,
        allowedTypes: (fixture['allowedTypes'] as List).cast<String>().toSet(),
        linkContext: linkContext,
      );

      expect(changelogResult.errorMessage, isNull);
      expect(changelogResult.changelog, fixture['expectedChangelog']);
    });

    test('fails when no commits are available for the release', () {
      final result = buildReleaseChangelog(
        version: '0.0.1-dev.3',
        existingChangelog: '## 0.0.1-dev.2\n',
        commits: const [],
        latestTag: 'synthetic_pkg/0.0.1-dev.2',
        packageName: 'synthetic_pkg',
        allowedTypes: const {'feat', 'fix'},
      );

      expect(result.changelog, isNull);
      expect(result.section, isNull);
      expect(result.errorMessage, contains('No commits matching'));
    });
  });

  group('checkReleaseSafetyGate', () {
    test('passes when pubspec version matches latest tag', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.2'),
        latestTag: 'clay_core/0.0.1-dev.2',
        latestTagVersion: Version.parse('0.0.1-dev.2'),
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.passed, isTrue);
      expect(result.failure, isNull);
      expect(result.errorMessage, isNull);
    });

    test('fails when pubspec is ahead of latest tag', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.3'),
        latestTag: 'clay_core/0.0.1-dev.2',
        latestTagVersion: Version.parse('0.0.1-dev.2'),
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.passed, isFalse);
      expect(result.failure, ReleaseSafetyFailure.pubspecAheadOfTag);
      expect(result.errorMessage, contains('ahead of latest release tag'));
      expect(result.errorMessage, contains('clay_core/0.0.1-dev.3'));
    });

    test('fails when pubspec is behind latest tag', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.1'),
        latestTag: 'clay_core/0.0.1-dev.2',
        latestTagVersion: Version.parse('0.0.1-dev.2'),
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.passed, isFalse);
      expect(result.failure, ReleaseSafetyFailure.pubspecBehindTag);
      expect(result.errorMessage, contains('behind latest release tag'));
      expect(result.errorMessage, contains('--allow-unsafe-bump'));
    });

    test('fails when no release tags exist', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.2'),
        latestTag: null,
        latestTagVersion: null,
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
      );

      expect(result.passed, isFalse);
      expect(result.failure, ReleaseSafetyFailure.noReleaseTag);
      expect(result.errorMessage, contains('No release tag found'));
      expect(result.errorMessage, contains('clay_core/0.0.1-dev.2'));
    });

    test('allowUnsafeBump skips version equality check', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.3'),
        latestTag: 'clay_core/0.0.1-dev.2',
        latestTagVersion: Version.parse('0.0.1-dev.2'),
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
        allowUnsafeBump: true,
      );

      expect(result.passed, isTrue);
      expect(result.failure, isNull);
      expect(result.errorMessage, isNull);
    });

    test('allowUnsafeBump still requires an existing release tag', () {
      final result = checkReleaseSafetyGate(
        currentVersion: Version.parse('0.0.1-dev.2'),
        latestTag: null,
        latestTagVersion: null,
        tagFormat: '{name}/{version}',
        packageName: 'clay_core',
        allowUnsafeBump: true,
      );

      expect(result.passed, isFalse);
      expect(result.failure, ReleaseSafetyFailure.noReleaseTag);
    });
  });

  group('resolveLatestTagWithSafetyGate', () {
    test('passes when latest tag matches pubspec version', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');

      final result = resolveLatestTagWithSafetyGate(
        gitRoot: tempRoot,
        tagFormat: '{name}/{version}',
        packageName: 'synthetic_pkg',
        currentVersion: Version.parse('0.0.1-dev.2'),
      );

      expect(result.errorMessage, isNull);
      expect(result.latestTag, 'synthetic_pkg/0.0.1-dev.2');
      expect(result.latestTagVersion, Version.parse('0.0.1-dev.2'));
    });

    test('fails when no tags exist for the package', () {
      _initGitRepoWithCommit(tempRoot);

      final result = resolveLatestTagWithSafetyGate(
        gitRoot: tempRoot,
        tagFormat: '{name}/{version}',
        packageName: 'synthetic_pkg',
        currentVersion: Version.parse('0.0.1-dev.2'),
      );

      expect(result.latestTag, isNull);
      expect(result.latestTagVersion, isNull);
      expect(result.errorMessage, contains('No release tag found'));
    });
  });

  group('collectCommitsSinceTag', () {
    test('returns commits since the latest tag in chronological order', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'chore: unrelated root change',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-3.txt',
        message: 'fix(synthetic_pkg): handle missing config',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-4.txt',
        message: 'feat(other_pkg): ignore me',
      );

      final result = collectCommitsSinceTag(
        gitRoot: tempRoot,
        latestTag: 'synthetic_pkg/0.0.1-dev.2',
      );

      expect(result.errorMessage, isNull);
      expect(
        result.commits!.map((commit) => commit.subject).toList(),
        [
          'chore: unrelated root change',
          'feat(synthetic_pkg): add preview command',
          'fix(synthetic_pkg): handle missing config',
          'feat(other_pkg): ignore me',
        ],
      );
    });

    test('preserves commit bodies for breaking change detection', () {
      _initGitRepoWithCommit(tempRoot);
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _runGit(tempRoot, [
        'commit',
        '--allow-empty',
        '-m',
        'feat(synthetic_pkg): reshape preview API',
        '-m',
        'BREAKING CHANGE: preview command flags were renamed.',
      ]);

      final result = collectCommitsSinceTag(
        gitRoot: tempRoot,
        latestTag: 'synthetic_pkg/0.0.1-dev.2',
      );

      expect(result.errorMessage, isNull);
      expect(result.commits, hasLength(1));
      expect(
        result.commits!.single.subject,
        'feat(synthetic_pkg): reshape preview API',
      );
      expect(
        result.commits!.single.body,
        contains('BREAKING CHANGE'),
      );
    });
  });

  group('collectScopedCommitsSinceTag', () {
    test('integration: collects scoped commits after safety gate passes', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'fix(synthetic_pkg): handle missing config (#43)',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-3.txt',
        message: 'chore: update CI',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-4.txt',
        message: 'feat(other_pkg): ignore me',
      );

      final safetyResult = resolveLatestTagWithSafetyGate(
        gitRoot: tempRoot,
        tagFormat: '{name}/{version}',
        packageName: 'synthetic_pkg',
        currentVersion: Version.parse('0.0.1-dev.2'),
      );
      expect(safetyResult.errorMessage, isNull);

      final commitsResult = collectScopedCommitsSinceTag(
        gitRoot: tempRoot,
        latestTag: safetyResult.latestTag!,
        allowedScopes: {'synthetic_pkg'},
        allowedTypes: const {
          'feat',
          'fix',
          'docs',
          'refactor',
          'test',
          'build',
        },
      );

      expect(commitsResult.errorMessage, isNull);
      expect(commitsResult.commits, hasLength(2));
      expect(commitsResult.commits!.map((commit) => commit.subject).toList(), [
        'feat(synthetic_pkg): add preview command',
        'fix(synthetic_pkg): handle missing config (#43)',
      ]);
    });
  });

  group('buildPrepareReleasePlan', () {
    test('builds a release plan for a valid fixture repository', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'fix(synthetic_pkg): handle missing config (#43)',
      );

      final result = buildPrepareReleasePlan(
        cwd: packageDir.path,
        tagFormat: '{name}/{version}',
        commitTypesInput: 'feat,fix,docs,refactor,test,build',
      );

      expect(result.errorMessage, isNull);
      final plan = result.plan!;
      expect(plan.packageName, 'synthetic_pkg');
      expect(plan.latestTag, 'synthetic_pkg/0.0.1-dev.2');
      expect(plan.currentVersion, Version.parse('0.0.1-dev.2'));
      expect(plan.nextVersion, Version.parse('0.1.0'));
      expect(plan.commits, hasLength(2));
      expect(plan.changelogSection, contains('## 0.1.0'));
      expect(
        plan.suggestedCommitMessage,
        'chore(synthetic_pkg): release 0.1.0',
      );
    });

    test('filters commits by --scopes instead of the package name', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/coverde_cli');
      _writePackage(
        packageDir: packageDir,
        name: 'coverde',
        version: '0.4.1',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'coverde-v0.4.1');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(coverde-cli): add transform command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'feat(coverde): should be ignored',
      );

      final result = buildPrepareReleasePlan(
        cwd: packageDir.path,
        tagFormat: '{name}-v{version}',
        commitTypesInput: 'feat,fix,docs,refactor,perf,test,build,chore',
        scopesInput: 'coverde-cli',
      );

      expect(result.errorMessage, isNull);
      final plan = result.plan!;
      expect(plan.packageName, 'coverde');
      expect(plan.latestTag, 'coverde-v0.4.1');
      expect(plan.nextVersion, Version.parse('0.5.0'));
      expect(plan.commits, hasLength(1));
      expect(
        plan.commits.single.subject,
        'feat(coverde-cli): add transform command',
      );
      expect(
        plan.suggestedCommitMessage,
        'chore(coverde): release 0.5.0',
      );
    });

    test('linkifies changelog entries from pubspec repository metadata', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
        repository:
            'https://github.com/example/clay/tree/main/packages/synthetic_pkg',
        issueTracker: 'https://github.com/example/clay/issues',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'fix(synthetic_pkg): handle missing config (#43)',
      );

      final result = buildPrepareReleasePlan(
        cwd: packageDir.path,
        tagFormat: '{name}/{version}',
        commitTypesInput: 'feat,fix,docs,refactor,test,build',
        explicitBump: ExplicitVersionBump.build,
      );

      expect(result.errorMessage, isNull);
      final plan = result.plan!;
      expect(
        plan.changelogSection,
        contains(
          '([#43](https://github.com/example/clay/issues/43))',
        ),
      );
      expect(
        plan.changelogSection,
        contains('https://github.com/example/clay/commit/'),
      );
    });
  });

  group('updatePubspecVersionLine', () {
    test('replaces only the version line', () {
      const original = '''
name: synthetic_pkg
description: A test package
version: 0.0.1-dev.2
environment:
  sdk: ^3.0.0
''';

      final result = updatePubspecVersionLine(
        pubspecContents: original,
        newVersion: '0.1.0',
      );

      expect(result.errorMessage, isNull);
      expect(result.contents, contains('name: synthetic_pkg'));
      expect(result.contents, contains('description: A test package'));
      expect(result.contents, contains('version: 0.1.0'));
      expect(result.contents, isNot(contains('version: 0.0.1-dev.2')));
    });

    test('updates quoted version values', () {
      const original = '''
name: synthetic_pkg
version: "0.0.1-dev.2"
''';

      final result = updatePubspecVersionLine(
        pubspecContents: original,
        newVersion: '0.1.0',
      );

      expect(result.errorMessage, isNull);
      expect(result.contents, contains('version: 0.1.0'));
      expect(result.contents, isNot(contains('0.0.1-dev.2')));
    });

    test('fails when version line is missing', () {
      final result = updatePubspecVersionLine(
        pubspecContents: 'name: synthetic_pkg\n',
        newVersion: '0.1.0',
      );

      expect(result.contents, isNull);
      expect(result.errorMessage, contains('version line'));
    });
  });

  group('applyPrepareReleasePlan', () {
    PrepareReleasePlan buildFixturePlan(Directory packageDir) {
      _initGitRepoWithCommit(tempRoot);
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'fix(synthetic_pkg): handle missing config (#43)',
      );

      final planResult = buildPrepareReleasePlan(
        cwd: packageDir.path,
        tagFormat: '{name}/{version}',
        commitTypesInput: 'feat,fix,docs,refactor,test,build',
      );
      expect(planResult.errorMessage, isNull);
      return planResult.plan!;
    }

    test('updates pubspec version and prepends changelog', () {
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      final plan = buildFixturePlan(packageDir);
      final pubspecFile = File('${packageDir.path}/pubspec.yaml');
      final changelogFile = File('${packageDir.path}/CHANGELOG.md');
      final pubspecBefore = pubspecFile.readAsStringSync();
      final changelogBefore = changelogFile.readAsStringSync();

      final result = applyPrepareReleasePlan(plan);

      expect(result.applied, isTrue);
      expect(result.errorMessage, isNull);
      expect(
        readPubspecNameAndVersion(pubspecFile).version,
        '0.1.0',
      );
      expect(pubspecFile.readAsStringSync(), isNot(pubspecBefore));
      expect(
        changelogFile.readAsStringSync(),
        startsWith('## 0.1.0'),
      );
      expect(
        changelogFile.readAsStringSync(),
        contains(changelogBefore.trim()),
      );
    });

    test('only changes the version line in pubspec.yaml', () {
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg')
        ..createSync(recursive: true);
      File('${packageDir.path}/pubspec.yaml').writeAsStringSync('''
name: synthetic_pkg
description: Keep this line intact
version: 0.0.1-dev.2
environment:
  sdk: ^3.0.0
''');
      File('${packageDir.path}/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n');
      _initGitRepo(tempRoot);
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );

      final planResult = buildPrepareReleasePlan(
        cwd: packageDir.path,
        tagFormat: '{name}/{version}',
        commitTypesInput: 'feat,fix,docs,refactor,test,build',
      );
      expect(planResult.errorMessage, isNull);

      final result = applyPrepareReleasePlan(planResult.plan!);

      expect(result.applied, isTrue);
      final updated =
          File('${packageDir.path}/pubspec.yaml').readAsStringSync();
      expect(updated, contains('description: Keep this line intact'));
      expect(updated, contains('environment:\n  sdk: ^3.0.0'));
      expect(updated, contains('version: 0.1.0'));
    });

    test('rolls back pubspec when changelog write fails', () {
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      final plan = buildFixturePlan(packageDir);
      final pubspecFile = File('${packageDir.path}/pubspec.yaml');
      final changelogFile = File('${packageDir.path}/CHANGELOG.md');
      final pubspecBefore = pubspecFile.readAsStringSync();

      _runChmod(changelogFile.path, '444');

      addTearDown(() {
        if (changelogFile.existsSync()) {
          _runChmod(changelogFile.path, '644');
        }
      });

      final result = applyPrepareReleasePlan(plan);

      expect(result.applied, isFalse);
      expect(result.errorMessage, contains('CHANGELOG.md'));
      expect(result.errorMessage, contains('rolled back'));
      expect(pubspecFile.readAsStringSync(), pubspecBefore);
    });
  });

  group('parsePrepareReleaseCliOptions', () {
    test('returns help mode for --help', () {
      final options = parsePrepareReleaseCliOptions(['--help']);

      expect(options, isNotNull);
      expect(options!.showHelp, isTrue);
    });

    test('returns null when required options are missing', () {
      expect(parsePrepareReleaseCliOptions([]), isNull);
      expect(
        parsePrepareReleaseCliOptions(['--cwd', 'packages/foo']),
        isNull,
      );
    });

    test('parses required options', () {
      final options = parsePrepareReleaseCliOptions([
        '--cwd',
        'packages/synthetic_pkg',
        '--tag-format',
        '{name}/{version}',
        '--commit-types',
        'feat,fix',
      ]);

      expect(options, isNotNull);
      expect(options!.showHelp, isFalse);
      expect(options.cwd, 'packages/synthetic_pkg');
      expect(options.tagFormat, '{name}/{version}');
      expect(options.commitTypes, 'feat,fix');
      expect(options.scopes, isNull);
      expect(options.explicitBump, isNull);
      expect(options.explicitVersionText, isNull);
      expect(options.allowUnsafeBump, isFalse);
    });

    test('parses --scopes override', () {
      final options = parsePrepareReleaseCliOptions([
        '--cwd',
        'packages/coverde_cli',
        '--tag-format',
        '{name}-v{version}',
        '--commit-types',
        'feat,fix',
        '--scopes',
        'coverde-cli',
      ]);

      expect(options, isNotNull);
      expect(options!.scopes, 'coverde-cli');
    });

    test('parses bump override flags', () {
      final options = parsePrepareReleaseCliOptions([
        '--cwd',
        'packages/synthetic_pkg',
        '--tag-format',
        '{name}/{version}',
        '--commit-types',
        'feat,fix',
        '--bump',
        'patch',
        '--allow-unsafe-bump',
      ]);

      expect(options, isNotNull);
      expect(options!.explicitBump, ExplicitVersionBump.patch);
      expect(options.explicitVersionText, isNull);
      expect(options.allowUnsafeBump, isTrue);
    });

    test('parses explicit version override', () {
      final options = parsePrepareReleaseCliOptions([
        '--cwd',
        'packages/synthetic_pkg',
        '--tag-format',
        '{name}/{version}',
        '--commit-types',
        'feat,fix',
        '--version',
        '0.0.1-dev.99',
      ]);

      expect(options, isNotNull);
      expect(options!.explicitBump, isNull);
      expect(options.explicitVersionText, '0.0.1-dev.99');
    });

    test('rejects mutually exclusive bump and version overrides', () {
      expect(
        parsePrepareReleaseCliOptions([
          '--cwd',
          'packages/synthetic_pkg',
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat',
          '--bump',
          'patch',
          '--version',
          '0.0.1-dev.99',
        ]),
        isNull,
      );
    });

    test('rejects invalid bump values', () {
      expect(
        parsePrepareReleaseCliOptions([
          '--cwd',
          'packages/synthetic_pkg',
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat',
          '--bump',
          'invalid',
        ]),
        isNull,
      );
    });

    test('parses apply flag', () {
      final options = parsePrepareReleaseCliOptions([
        '--cwd',
        'packages/synthetic_pkg',
        '--tag-format',
        '{name}/{version}',
        '--commit-types',
        'feat,fix',
        '--apply',
      ]);

      expect(options, isNotNull);
      expect(options!.apply, isTrue);
    });

    test('rejects unknown flags', () {
      expect(
        parsePrepareReleaseCliOptions([
          '--cwd',
          'packages/synthetic_pkg',
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat',
          '--unknown-flag',
        ]),
        isNull,
      );
    });
  });

  group('prepare release CLI', () {
    test('dry-run prints plan without modifying package files', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );

      final pubspecBefore =
          File('${packageDir.path}/pubspec.yaml').readAsStringSync();
      final changelogBefore =
          File('${packageDir.path}/CHANGELOG.md').readAsStringSync();

      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
        ],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('Dry run'));
      expect(result.stdout, contains('package_name=synthetic_pkg'));
      expect(result.stdout, contains('release_version=0.1.0'));
      expect(result.stdout, contains('latest_tag=synthetic_pkg/0.0.1-dev.2'));
      expect(
        result.stdout,
        contains('chore(synthetic_pkg): release 0.1.0'),
      );
      expect(
        File('${packageDir.path}/pubspec.yaml').readAsStringSync(),
        pubspecBefore,
      );
      expect(
        File('${packageDir.path}/CHANGELOG.md').readAsStringSync(),
        changelogBefore,
      );
    });

    test('--help exits zero and documents required flags', () {
      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: ['--help'],
      );

      expect(result.exitCode, 0);
      expect(result.stdout, contains('--cwd'));
      expect(result.stdout, contains('--tag-format'));
      expect(result.stdout, contains('--commit-types'));
      expect(result.stdout, contains('--scopes'));
      expect(result.stdout, contains('--bump'));
      expect(result.stdout, contains('--version'));
      expect(result.stdout, contains('allow-unsafe-bump'));
      expect(result.stdout, contains('apply'));
    });

    test('missing required flags exits 64', () {
      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: ['--cwd', 'packages/synthetic_pkg'],
      );

      expect(result.exitCode, 64);
    });

    test('--bump patch produces expected next version in dry-run output', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );

      final pubspecBefore =
          File('${packageDir.path}/pubspec.yaml').readAsStringSync();
      final changelogBefore =
          File('${packageDir.path}/CHANGELOG.md').readAsStringSync();

      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
          '--bump',
          'patch',
        ],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('release_version=0.0.2'));
      expect(
        File('${packageDir.path}/pubspec.yaml').readAsStringSync(),
        pubspecBefore,
      );
      expect(
        File('${packageDir.path}/CHANGELOG.md').readAsStringSync(),
        changelogBefore,
      );
    });

    test('--version sets exact next version in dry-run output', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );

      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
          '--version',
          '0.0.1-dev.99',
        ],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('release_version=0.0.1-dev.99'));
    });

    test('--bump and --version together exit 64', () {
      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          'packages/synthetic_pkg',
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat',
          '--bump',
          'patch',
          '--version',
          '0.0.1-dev.99',
        ],
      );

      expect(result.exitCode, 64);
    });

    test('--allow-unsafe-bump allows dry-run when pubspec is ahead of tag', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _writePubspec(
        directory: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.3',
      );
      _gitCommitAll(
        tempRoot,
        message: 'chore(synthetic_pkg): bump dev version',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );

      final withoutFlag = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
        ],
      );
      expect(withoutFlag.exitCode, 1);
      expect(withoutFlag.stderr, contains('ahead of latest release tag'));

      final withFlag = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
          '--allow-unsafe-bump',
        ],
      );

      expect(withFlag.exitCode, 0, reason: withFlag.stderr.toString());
      expect(withFlag.stdout, contains('release_version=0.1.0'));
    });

    test('--apply writes pubspec version and prepends changelog', () {
      _initGitRepoWithCommit(tempRoot);
      final packageDir = Directory('${tempRoot.path}/packages/synthetic_pkg');
      _writePackage(
        packageDir: packageDir,
        name: 'synthetic_pkg',
        version: '0.0.1-dev.2',
      );
      _gitCommitAll(tempRoot, message: 'chore: add package scaffold');
      _gitCreateAnnotatedTag(tempRoot, 'synthetic_pkg/0.0.1-dev.2');
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-1.txt',
        message: 'feat(synthetic_pkg): add preview command',
      );
      _gitCommitWithFileChange(
        tempRoot,
        fileName: 'change-2.txt',
        message: 'fix(synthetic_pkg): handle missing config (#43)',
      );

      final rootMarkerBefore =
          File('${tempRoot.path}/README.md').readAsStringSync();

      final result = _runPrepareReleaseCli(
        repoRoot: tempRoot,
        arguments: [
          '--cwd',
          packageDir.path,
          '--tag-format',
          '{name}/{version}',
          '--commit-types',
          'feat,fix,docs,refactor,test,build',
          '--apply',
        ],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('Applied release changes'));
      expect(result.stdout, contains('release_version=0.1.0'));
      expect(
        readPubspecNameAndVersion(File('${packageDir.path}/pubspec.yaml'))
            .version,
        '0.1.0',
      );
      expect(
        File('${packageDir.path}/CHANGELOG.md').readAsStringSync(),
        contains('## 0.1.0'),
      );
      expect(
        File('${tempRoot.path}/README.md').readAsStringSync(),
        rootMarkerBefore,
      );
    });
  });
}

File _writePubspec({
  required Directory directory,
  required String name,
  required String version,
  String? repository,
  String? issueTracker,
}) {
  directory.createSync(recursive: true);
  final buffer = StringBuffer()
    ..writeln('name: $name')
    ..writeln('version: $version');
  if (repository != null) {
    buffer.writeln('repository: $repository');
  }
  if (issueTracker != null) {
    buffer.writeln('issue_tracker: $issueTracker');
  }
  final pubspecFile = File('${directory.path}/pubspec.yaml')
    ..writeAsStringSync(buffer.toString());
  return pubspecFile;
}

void _writePackage({
  required Directory packageDir,
  required String name,
  required String version,
  String? repository,
  String? issueTracker,
}) {
  _writePubspec(
    directory: packageDir,
    name: name,
    version: version,
    repository: repository,
    issueTracker: issueTracker,
  );
  File('${packageDir.path}/CHANGELOG.md').writeAsStringSync('# Changelog\n');
}

void _initGitRepo(Directory repoRoot) {
  _runGit(repoRoot, ['init']);
  _runGit(repoRoot, ['config', 'user.email', 'test@example.com']);
  _runGit(repoRoot, ['config', 'user.name', 'Test User']);
}

void _initGitRepoWithCommit(Directory repoRoot) {
  _initGitRepo(repoRoot);
  File('${repoRoot.path}/README.md').writeAsStringSync('# test repo\n');
  _gitCommitAll(repoRoot, message: 'init');
}

void _gitCommitAll(Directory repoRoot, {required String message}) {
  _runGit(repoRoot, ['add', '-A']);
  _runGit(repoRoot, ['commit', '-m', message]);
}

void _gitCommitWithFileChange(
  Directory repoRoot, {
  required String fileName,
  required String message,
}) {
  File('${repoRoot.path}/$fileName').writeAsStringSync('$message\n');
  _gitCommitAll(repoRoot, message: message);
}

void _gitCreateAnnotatedTag(Directory repoRoot, String tagName) {
  _runGit(repoRoot, ['tag', '-a', tagName, '-m', tagName]);
}

ProcessResult _runGit(Directory repoRoot, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: repoRoot.path,
  );
  expect(
    result.exitCode,
    0,
    reason: 'git ${arguments.join(' ')} failed: ${result.stderr}',
  );
  return result;
}

void _runChmod(String path, String mode) {
  final result = Process.runSync('chmod', [mode, path]);
  expect(
    result.exitCode,
    0,
    reason: 'chmod $mode $path failed: ${result.stderr}',
  );
}

File _readTestFixture(String name) {
  for (final path in [
    'tool/prepare_package_release/test/fixtures/$name',
    'test/fixtures/$name',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }

  fail('Fixture not found: $name (cwd: ${Directory.current.path})');
}

ProcessResult _runPrepareReleaseCli({
  required Directory repoRoot,
  required List<String> arguments,
}) {
  final coverdeRepoRoot = _resolveCoverdeRepoRoot();
  final scriptPath =
      '${coverdeRepoRoot.path}/tool/prepare_package_release/prepare_package_release.dart';
  return Process.runSync(
    'dart',
    ['run', scriptPath, ...arguments],
    workingDirectory: coverdeRepoRoot.path,
  );
}

Directory _resolveCoverdeRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File(
      '${dir.path}/tool/prepare_package_release/prepare_package_release.dart',
    );
    if (candidate.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  fail(
    'Could not resolve coverde repo root (cwd: ${Directory.current.path})',
  );
}
