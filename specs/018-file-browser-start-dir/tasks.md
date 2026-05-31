# Tasks — file-browser start directory

- [x] **T001** `file_browser_start.dart`: mode constants + `startPathCandidates` + `LastPathStore`.
- [x] **T002** Settings: `fileBrowserStartDir` (default claudeCodeFolder) + setter + prefs.
- [x] **T003** `initialize(connectionId, paneId)`: mode-aware candidate chain + home fallback.
- [x] **T004** Remember the path per connection on each successful `loadDirectory`.
- [x] **T005** `FileBrowserScreen` passes connectionId; Settings "File browser" → "Open at" picker.
- [x] **T006** [TDD] Tests: candidate ordering; store round-trip/persist/isolation; setting round-trip (+11).
- [x] **T007** Gate: analyze exit 0; flutter test 393.
- [ ] **T008** Commit, push, PR; CI green.
