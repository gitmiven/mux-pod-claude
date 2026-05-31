# Tasks — more file types (CSV/ZIP in-app, rest external)

- [x] **T001** FileViewerType + csv/archive/external (labels, fromName, isExternal) + defaults.
- [x] **T002** Pure `parseCsvRows` + `listZipEntries` (csv 8.x / archive 4.x).
- [x] **T003** FileViewerScreen: CSV DataTable + archive entry list.
- [x] **T004** Streaming `SftpBrowserService.downloadToFile`; `downloadToTemp` in the provider.
- [x] **T005** Browser routes external → download + `OpenFilex.open` (errors → SnackBar).
- [x] **T006** Settings type picker → dropdown (6 types).
- [x] **T007** [TDD] Tests: csv/zip parsers; new types/defaults/isExternal (+8).
- [x] **T008** Gate: analyze exit 0; flutter test 442. open_filex/image_picker provider conflict ruled out.
- [ ] **T009** Commit, push, PR; CI green; release-build verifies Android on tag.
