# Tasks — render embedded images in the Markdown viewer

- [x] **T001** Pure `resolveRemoteImagePath` (relative/absolute/network/data, percent-decode).
- [x] **T002** `_markdownImage` imageBuilder: data inline / http(s) network / else SFTP.
- [x] **T003** `_SftpImage` widget: cached SFTP fetch + loading/broken placeholders.
- [x] **T004** Wire `imageBuilder` into `Markdown(...)`.
- [x] **T005** [TDD] Resolver tests (+6).
- [x] **T006** Gate: analyze exit 0; flutter test 399.
- [ ] **T007** Commit, push, PR; CI green.
