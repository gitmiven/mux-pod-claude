# Plan — 021 full-width TUI backgrounds

## Finding
The parser ALREADY carries ANSI state across lines (`parseLines` threads `endStyle`), and the view uses
it (`_getParsedLines` → `parser.parseLines`). The only missing piece was rendering the fill.

## Fix
- `AnsiParser.lineFillColor(ParsedLine)` (pure): the bg active at the line's end (inverse → fg), or null
  for default — derived from the carried `endStyle`.
- `AnsiTextView` itemBuilder: wrap each line in `ColoredBox(color: fillColor)` when non-null. The
  ListView gives items tight full width, so the box fills the row (and the whole pane width with
  horizontal scroll via the existing SizedBox(terminalWidth)).

## Files
- Modified: ansi_parser.dart (+lineFillColor), ansi_text_view.dart (ColoredBox wrap).
- Tests: ansi_parser_test.dart (+4: carry across lines, plain=null, SGR49 ends fill, inverse=fg).

## Verification
analyze exit 0; flutter test 405. Manual: mc renders blue full-width incl. empty rows; shell output
(resets before newline) unchanged.
