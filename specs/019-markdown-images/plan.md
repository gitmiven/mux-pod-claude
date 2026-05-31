# Plan — 019 markdown images

## Design
- Pure `resolveRemoteImagePath(markdownFilePath, Uri)` (lib/services/viewer/markdown_image.dart):
  http/https/data → null; relative → resolved against the .md dir (posix); absolute → normalised;
  percent-decoded.
- FileViewerScreen._buildMarkdown passes `imageBuilder: _markdownImage`:
  - data: → Image.memory(uri.data.contentAsBytes())
  - http/https → Image.network
  - else → resolveRemoteImagePath → `_SftpImage(path)`
- `_SftpImage` (ConsumerStatefulWidget): fetches bytes over SFTP once (readFileBytes, size-capped),
  shows a spinner then Image.memory, or a broken-image icon on error — one bad image never blanks the
  doc.

## Files
- New: markdown_image.dart; markdown_image_test.dart.
- Modified: file_viewer_screen.dart (imageBuilder + _SftpImage).

## Verification
analyze exit 0; flutter test 399 (+6 resolver cases: relative/`..`/absolute/network/data/encoded/empty).
