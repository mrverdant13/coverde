import 'package:args/command_runner.dart';

/// Extended utils on the command implementation.
extension ExtendedCommand on Command {
  /// Validate command multi-options.
  List<String> checkMultiOption({
    required String multiOptionKey,
    required String multiOptionName,
  }) {
    if (argResults == null) usageException('Missing arguments.');
    final maybeMultiOption = argResults![multiOptionKey] as List<String>;
    return maybeMultiOption;
  }

  /// Validate command option.
  String checkOption({
    required String optionKey,
    required String optionName,
  }) {
    if (argResults == null) usageException('Missing arguments.');
    final maybeOption = argResults![optionKey] as String?;
    if (maybeOption == null || maybeOption.isEmpty) {
      usageException('The `$optionName` is required.');
    }
    return maybeOption;
  }

  /// Validate command flag.
  bool checkFlag({
    required String flagKey,
    required String flagName,
  }) {
    if (argResults == null) usageException('Missing arguments.');
    final maybeFlag = argResults![flagKey] as bool?;
    if (maybeFlag == null) usageException('The `$flagName` flag is required.');
    return maybeFlag;
  }

  /// Validate coverage value.
  T checkCoverage<T extends num>({
    required T coverage,
    required String valueName,
  }) {
    if (coverage.isNegative) {
      usageException('The $valueName value should be positive.');
    } else if (coverage > 100) {
      usageException('The $valueName value should not be greater than 100.');
    }
    return coverage;
  }
}
