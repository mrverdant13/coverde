import 'package:collection/collection.dart';
import 'package:coverde/src/utils/execution_mode.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/universal_io.dart';

/// {@template operating_system}
/// The operating system of the current machine.
/// {@endtemplate}
enum OperatingSystem {
  /// Linux
  linux('linux'),

  /// macOS
  macos('macos'),

  /// Windows
  windows('windows'),
  ;

  const OperatingSystem(this.identifier);

  /// The identifier of the operating system.
  final String identifier;
}

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

/// The operating system of the current machine.
@pragma('vm:platform-const')
@pragma('vm:prefer-inline')
@pragma('dart2js:prefer-inline')
OperatingSystem get operatingSystem {
  OperatingSystem? operatingSystem;
  operatingSystem = [
    ...OperatingSystem.values,
    null,
  ].firstWhere(
    (e) => e?.identifier == Platform.operatingSystem,
  );
  if (isDebugMode && debugOperatingSystemIdentifier != null) {
    operatingSystem = OperatingSystem.values.firstWhereOrNull(
      (e) => e.identifier == debugOperatingSystemIdentifier,
    );
  }
  if (operatingSystem != null) return operatingSystem;
  throw UnsupportedError(
    'Unsupported operating system: ${Platform.operatingSystem}',
  );
}
