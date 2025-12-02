import 'package:coverde/src/utils/utils.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/universal_io.dart';

String? _debugOperatingSystemIdentifier;

/// The overridden operating system identifier for debugging purposes.
@visibleForTesting
String? get debugOperatingSystemIdentifier => _debugOperatingSystemIdentifier;

/// Overrides the operating system identifier for debugging purposes.
@visibleForTesting
set debugOperatingSystemIdentifier(String? value) {
  // coverage:ignore-start
  if (!isDebugMode) {
    throw UnsupportedError(
      'Cannot modify `debugOperatingSystemIdentifier` in non-debug builds.',
    );
  }
  // coverage:ignore-end
  _debugOperatingSystemIdentifier = value;
}

/// The operating system identifier of the current machine.
@pragma('vm:platform-const')
@pragma('vm:prefer-inline')
@pragma('dart2js:prefer-inline')
String get operatingSystemIdentifier {
  if (isDebugMode && debugOperatingSystemIdentifier != null) {
    return debugOperatingSystemIdentifier!;
  }
  return Platform.operatingSystem;
}
