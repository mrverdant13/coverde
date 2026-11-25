import 'package:coverde/src/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('appendTraceContent', () {
    test('closes an open final record and leaves a closed one alone', () {
      final open = StringBuffer();
      appendTraceContent(open, 'SF:a.dart\nDA:1,1');
      expect(open.toString(), 'SF:a.dart\nDA:1,1\nend_of_record\n');

      final closed = StringBuffer();
      appendTraceContent(closed, 'SF:a.dart\nDA:1,1\nend_of_record\n');
      expect(closed.toString(), 'SF:a.dart\nDA:1,1\nend_of_record\n');

      final empty = StringBuffer('keep');
      appendTraceContent(empty, '');
      expect(empty.toString(), 'keep');
    });
  });
}
