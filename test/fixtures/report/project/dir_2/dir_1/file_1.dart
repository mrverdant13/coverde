extension ExtendedStringList on List<String> {
  void printEachWithQuotes([
    String quote = '"',
  ]) {
    for (final str in this) {
      // ignore: avoid_print
      print('$quote$str$quote');
    }
  }
}
