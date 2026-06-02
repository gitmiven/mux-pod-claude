# Spec quality checklist — 028 translate docs

- [x] Scope confirmed by user: docs/*.md + ios Info.plist; leave README.ja.md + 001–003 specs.
- [x] Targets enumerated (4 docs/*.md + ios/Runner/Info.plist); exclusions explicit.
- [x] Requirements testable (FR-001 prose+structure, FR-002 plist strings, FR-003 exclusions untouched, FR-004 gate).
- [x] Measurable SCs (SC-001 0 Japanese in targets, SC-002 markdown/XML valid, SC-003 exclusions unchanged, SC-004 gate).
- [x] Faithful translation; technical terms preserved; structure/links/code intact.
- [x] No behaviour change — docs + plist strings only.
- [x] Scope bounds: no README.ja, no spec archives, no test fixtures, no generated HTML/screens.
