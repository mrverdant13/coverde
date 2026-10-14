import 'dart:convert';

/// Returns `true` when [responseBody] lists [version] in its `versions` array.
///
/// Returns `false` for malformed JSON or unexpected response shapes.
bool versionListedInPubDevResponse(String responseBody, String version) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseBody);
  } on FormatException {
    return false;
  }

  if (decoded is! Map) {
    return false;
  }

  final versions = decoded['versions'];
  if (versions is! List) {
    return false;
  }

  for (final entry in versions) {
    if (entry is Map && entry['version'] == version) {
      return true;
    }
  }

  return false;
}

/// Polls pub.dev until [version] is listed for [packageName], or [timeout]
/// elapses.
///
/// Returns `0` when the version is found and a non-zero exit code on failure.
Future<int> waitForPubDevVersion({
  required String packageName,
  required String version,
  required Duration timeout,
  required Duration interval,
  required Future<String> Function(String packageName) fetchPackage,
  void Function(String message)? log,
  void Function(String message)? errorLog,
  DateTime Function()? now,
  Future<void> Function(Duration duration)? sleep,
}) async {
  final clock = now ?? DateTime.now;
  final wait = sleep ?? Future<void>.delayed;
  final deadline = clock().add(timeout);
  var attempt = 0;

  while (!clock().isAfter(deadline)) {
    attempt++;
    try {
      final responseBody = await fetchPackage(packageName);
      if (versionListedInPubDevResponse(responseBody, version)) {
        log?.call(
          'Found $packageName $version on pub.dev after $attempt '
          '${attempt == 1 ? 'attempt' : 'attempts'}.',
        );
        return 0;
      }

      log?.call(
        'Attempt $attempt: $packageName $version is not listed on pub.dev yet.',
      );
    } on PubDevPackageNotFoundException catch (error) {
      errorLog?.call(error.message);
      return 1;
    } on PubDevFetchException catch (error) {
      errorLog?.call(error.message);
      return 1;
    }

    if (clock().add(interval).isAfter(deadline)) {
      break;
    }

    await wait(interval);
  }

  errorLog?.call(
    'Timed out after ${timeout.inSeconds}s waiting for '
    '$packageName $version on pub.dev.',
  );
  return 1;
}

class PubDevPackageNotFoundException implements Exception {
  PubDevPackageNotFoundException(this.message);

  final String message;
}

class PubDevFetchException implements Exception {
  PubDevFetchException(this.message);

  final String message;
}
