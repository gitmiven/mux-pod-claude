# Tasks — open a file in an in-app viewer

- [x] **T001** `FileViewerType` enum + `forExtension` + `kDefaultFileViewers`.
- [x] **T002** Settings: `fileViewers` map (+ copyWith, JSON persist, defaults, set/remove setters).
- [x] **T003** `SftpBrowserService.readFileBytes` with size cap + `FileTooLargeException`.
- [x] **T004** `FileViewerScreen` — SFTP fetch + Image/Markdown/Text render + loading/error states.
- [x] **T005** Menu: `FileAction.openInViewer` "Open with <type>" between header and Rename (files only).
- [x] **T006** Browser: resolve type, push the viewer screen (nothing sent to the pane).
- [x] **T007** Settings UI: "File viewers" section — list + add/edit/remove.
- [x] **T008** Add `flutter_markdown_plus` dependency.
- [x] **T009** [TDD] Tests: type resolution; settings round-trip/persist; menu construction (+14).
- [x] **T010** Gate: analyze exit 0; flutter test 382.
- [ ] **T011** Commit, push, PR; CI green.
