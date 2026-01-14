import 'package:code_builder/code_builder.dart' as coder;

/// {@template coverde_cli.test_file_optimization_data}
/// Result of processing a single test file during optimization.
/// {@endtemplate}
class TestFileOptimizationData {
  /// {@macro coverde_cli.test_file_optimization_data}
  const TestFileOptimizationData({
    required this.testFileGroupStatement,
    required this.hasAsyncEntryPoint,
  });

  /// The statement that groups the test file.
  final coder.Code testFileGroupStatement;

  /// Whether the test file has an async entry point.
  final bool hasAsyncEntryPoint;
}
