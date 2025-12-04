/// The mode for the update check.
enum UpdateCheckMode {
  /// Disable the update check.
  disabled(
    'disabled',
    'Disable the update check.',
  ),

  /// Enable the update check with silent output, only prompting the user if an
  /// update is available, and ignoring any warnings and errors.
  enabled(
    'enabled',
    'Enable the update check with silent output, only prompting the user if an '
        'update is available, and ignoring any warnings and errors.',
  ),

  /// Enable the update check with verbose output.
  enabledVerbose(
    'enabled-verbose',
    'Enable the update check with verbose output.',
  ),
  ;

  const UpdateCheckMode(this.identifier, this.help);

  /// The identifier for the update check mode.
  final String identifier;

  /// The help message for the update check mode.
  final String help;
}
