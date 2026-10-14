import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:wait_for_pub_dev_version/wait_for_pub_dev_version.dart';

import 'package_configs.dart';

const defaultPollTimeout = Duration(minutes: 10);
const defaultPollInterval = Duration(seconds: 20);
const pubDevPackageApiBase = 'https://pub.dev/api/packages';
const maxFetchAttempts = 3;
const pubDevRequestTimeout = Duration(seconds: 30);

void main(List<String> arguments) async {
  final options = _readOptions(arguments);
  if (options == null) {
    _printUsage();
    exit(64);
  }

  if (packageConfigs[options.packageName] == null) {
    stderr
      ..writeln('Unknown package: ${options.packageName}')
      ..writeln('Supported packages: ${packageConfigs.keys.join(', ')}');
    exit(1);
  }

  final exitCode = await waitForPubDevVersion(
    packageName: options.packageName,
    version: options.version,
    timeout: options.timeout,
    interval: options.interval,
    fetchPackage: _fetchPubDevPackage,
    log: stdout.writeln,
    errorLog: stderr.writeln,
  );
  exit(exitCode);
}

Future<String> _fetchPubDevPackage(String packageName) async {
  final client = HttpClient()
    ..connectionTimeout = pubDevRequestTimeout
    ..idleTimeout = pubDevRequestTimeout;
  try {
    for (var attempt = 1; attempt <= maxFetchAttempts; attempt++) {
      try {
        final responseBody = await _fetchPubDevPackageAttempt(
          client,
          packageName,
        ).timeout(pubDevRequestTimeout);

        return responseBody;
      } on PubDevPackageNotFoundException {
        rethrow;
      } on PubDevFetchException catch (error) {
        final isLastAttempt = attempt == maxFetchAttempts;
        if (isLastAttempt) {
          throw PubDevFetchException(
            '${error.message} after $maxFetchAttempts attempts.',
          );
        }

        await Future<void>.delayed(Duration(seconds: attempt));
      } on TimeoutException catch (error) {
        final isLastAttempt = attempt == maxFetchAttempts;
        if (isLastAttempt) {
          throw PubDevFetchException(
            'Timed out fetching pub.dev package metadata for $packageName '
            'after $maxFetchAttempts attempts: $error',
          );
        }

        await Future<void>.delayed(Duration(seconds: attempt));
      } on Object catch (error) {
        final isLastAttempt = attempt == maxFetchAttempts;
        if (isLastAttempt) {
          throw PubDevFetchException(
            'Failed to fetch pub.dev package metadata for $packageName '
            'after $maxFetchAttempts attempts: $error',
          );
        }

        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    throw PubDevFetchException(
      'Failed to fetch pub.dev package metadata for $packageName.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<String> _fetchPubDevPackageAttempt(
  HttpClient client,
  String packageName,
) async {
  final request = await client.getUrl(
    Uri.parse('$pubDevPackageApiBase/$packageName'),
  );
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode == HttpStatus.notFound) {
    throw PubDevPackageNotFoundException(
      'Package not found on pub.dev: $packageName',
    );
  }

  if (response.statusCode != HttpStatus.ok) {
    throw PubDevFetchException(
      'pub.dev API returned HTTP ${response.statusCode} for $packageName',
    );
  }

  return responseBody;
}

class _WaitOptions {
  const _WaitOptions({
    required this.packageName,
    required this.version,
    required this.timeout,
    required this.interval,
  });

  final String packageName;
  final String version;
  final Duration timeout;
  final Duration interval;
}

_WaitOptions? _readOptions(List<String> arguments) {
  String? packageName;
  String? version;
  var timeout = defaultPollTimeout;
  var interval = defaultPollInterval;

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];

    if (argument == '--package') {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Missing value for --package');
        return null;
      }
      packageName = arguments[++index];
      continue;
    }

    const packagePrefix = '--package=';
    if (argument.startsWith(packagePrefix)) {
      final value = argument.substring(packagePrefix.length);
      if (value.isEmpty) {
        stderr.writeln('Missing value for --package');
        return null;
      }
      packageName = value;
      continue;
    }

    if (argument == '--version') {
      if (index + 1 >= arguments.length) {
        stderr.writeln('Missing value for --version');
        return null;
      }
      version = arguments[++index];
      continue;
    }

    const versionPrefix = '--version=';
    if (argument.startsWith(versionPrefix)) {
      final value = argument.substring(versionPrefix.length);
      if (value.isEmpty) {
        stderr.writeln('Missing value for --version');
        return null;
      }
      version = value;
      continue;
    }

    if (argument == '--timeout') {
      final parsed = _readDurationArgument(
        arguments,
        index,
        defaultPollTimeout,
        '--timeout',
      );
      if (parsed == null) {
        return null;
      }
      timeout = parsed.value;
      index = parsed.nextIndex;
      continue;
    }

    const timeoutPrefix = '--timeout=';
    if (argument.startsWith(timeoutPrefix)) {
      final parsed = _parseDurationSeconds(
        argument.substring(timeoutPrefix.length),
        '--timeout',
      );
      if (parsed == null) {
        return null;
      }
      timeout = parsed;
      continue;
    }

    if (argument == '--interval') {
      final parsed = _readDurationArgument(
        arguments,
        index,
        defaultPollInterval,
        '--interval',
      );
      if (parsed == null) {
        return null;
      }
      interval = parsed.value;
      index = parsed.nextIndex;
      continue;
    }

    const intervalPrefix = '--interval=';
    if (argument.startsWith(intervalPrefix)) {
      final parsed = _parseDurationSeconds(
        argument.substring(intervalPrefix.length),
        '--interval',
      );
      if (parsed == null) {
        return null;
      }
      interval = parsed;
      continue;
    }

    stderr.writeln('Unknown argument: $argument');
    return null;
  }

  if (packageName == null) {
    stderr.writeln('Missing required --package argument');
    return null;
  }

  if (version == null) {
    stderr.writeln('Missing required --version argument');
    return null;
  }

  return _WaitOptions(
    packageName: packageName,
    version: version,
    timeout: timeout,
    interval: interval,
  );
}

({Duration value, int nextIndex})? _readDurationArgument(
  List<String> arguments,
  int index,
  Duration defaultValue,
  String flagName,
) {
  if (index + 1 >= arguments.length) {
    stderr.writeln('Missing value for $flagName');
    return null;
  }

  final parsed = _parseDurationSeconds(arguments[index + 1], flagName);
  if (parsed == null) {
    return null;
  }

  return (value: parsed, nextIndex: index + 1);
}

Duration? _parseDurationSeconds(String rawValue, String flagName) {
  final seconds = int.tryParse(rawValue);
  if (seconds == null || seconds <= 0) {
    stderr.writeln(
      'Invalid $flagName value: $rawValue (expected positive integer seconds)',
    );
    return null;
  }

  return Duration(seconds: seconds);
}

void _printUsage() {
  stderr
    ..writeln(
      'Usage: dart run tools/wait_for_pub_dev_version/wait_for_pub_dev_version.dart '
      '--package <name> --version <version> '
      '[--timeout <seconds>] [--interval <seconds>]',
    )
    ..writeln()
    ..writeln(
      'Polls pub.dev until the exact version appears in the package API.',
    )
    ..writeln(
      'Default timeout: ${defaultPollTimeout.inSeconds}s; '
      'default interval: ${defaultPollInterval.inSeconds}s.',
    )
    ..writeln()
    ..writeln('Supported packages: ${packageConfigs.keys.join(', ')}');
}
