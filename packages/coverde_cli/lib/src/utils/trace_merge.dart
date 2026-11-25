/// Appends [content] to [trace], closing an open final record when needed.
///
/// Each input may omit a trailing `end_of_record`. Joining those files without
/// closing the open record glues the next file's `SF:` into the same record.
void appendTraceContent(StringBuffer trace, String content) {
  if (content.isEmpty) return;
  trace.write(content);
  if (!content.endsWith('\n')) {
    trace.write('\n');
  }
  final trimmed = content.trimRight();
  if (trimmed.isNotEmpty && !trimmed.endsWith('end_of_record')) {
    trace.writeln('end_of_record');
  }
}
