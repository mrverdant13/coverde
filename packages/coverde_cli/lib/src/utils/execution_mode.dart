/// Whether the current execution mode is debug.
@pragma('vm:platform-const')
@pragma('vm:prefer-inline')
@pragma('dart2js:prefer-inline')
bool get isDebugMode {
  var isDebugMode = false;
  // Debug only assert.
  // ignore: prefer_asserts_with_message
  assert((() => isDebugMode = true)());
  return isDebugMode;
}
