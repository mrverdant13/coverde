import 'dart:io';

/// Generates `*_test.dart` files from `*_test.dart.tmp` templates in the given
/// directory.
///
/// The template files are kept unchanged.
void generateTestFromTemplate(Directory directory) {
  if (!directory.existsSync()) return;
  final files = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart.tmp'));
  for (final file in files) {
    final targetPath = file.path.replaceAll('_test.dart.tmp', '_test.dart');
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }
    file.copySync(targetPath);
  }
}

/// Deletes all `*_test.dart` files in the given directory.
void deleteTestFiles(Directory directory) {
  if (!directory.existsSync()) return;
  final files = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'));
  for (final file in files) {
    file.deleteSync();
  }
}
