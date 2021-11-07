extension ExtendedStringList on List<String> {
  void printEachWithQuotes([
    String quote = '"',
  ]) {
    for (final str in this) {
      print('$quote$str$quote');
    }
  }
}
