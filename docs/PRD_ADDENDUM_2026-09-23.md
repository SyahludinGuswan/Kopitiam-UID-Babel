# PRD Addendum: 23 September 2026

This addendum updates the PRD status after the REL-03 implementation and merge. It supplements `docs/PRD.md` without changing the business workflow or adding physical columns to business sheets.

## REL-03: optimistic concurrency and formula preservation

REL-03 is complete in source and CI through PR #7, merged by commit `f56e7ae`.

The backend now:

- Stores technical revision metadata in the separate `Kopitiam_Technical_Metadata` spreadsheet.
- Uses `REVISION_INDEX`, `REVISION_AUDIT`, and `METADATA_CONFIG`.
- Uses stable keys based on ULP, WO, and Temuan identity.
- Compares expected revision and fingerprint before writes and returns `REVISION_CONFLICT` for stale data.
- Serializes metadata check and commit with `LockService`.
- Writes only approved mutable cells, preserving formulas and immutable business fields.
- Keeps read endpoints compatible before metadata provisioning by returning empty revision tokens.
- Fails closed for revision-protected writes until Script Property `REVISION_METADATA_SPREADSHEET_ID` is configured.

No physical `Revision` column is added to business sheets, and no production spreadsheet or production data was changed.

## Updated non-functional requirement

For any synchronized WO or Temuan update, the client should retain the `_revision` and `_fingerprint` values returned by the read path and send them with the subsequent write. A stale token must stop the write rather than overwrite a newer change.

## Production provisioning requirement

Before enabling revision-protected writes in production:

1. Create or verify the separate technical metadata spreadsheet.
2. Configure Script Property `REVISION_METADATA_SPREADSHEET_ID` in the deployed backend project.
3. Run `setupBackend()` and verify `REVISION_INDEX`, `REVISION_AUDIT`, and `METADATA_CONFIG` headers.
4. Perform staging concurrency tests, formula-preservation tests, and stale-token conflict tests.
5. Deploy the same tested runtime bundle and retain rollback evidence.

## P2 hardening status

The following P2 source remediations are complete in source, regression tests, CI, and merged PRs:

- **JPEG structure/content validation:** PR #9, merged as commit `2a68eee`.
- **Photo processing and upload failure handling:** PR #10, merged as commit `72a4384`. Required WO photo upload failures fail closed with `PHOTO_UPLOAD_FAILED`, stored paths normalize both slash styles, and stale-lease handling uses fresh reads under lock in the selected runtime implementation.
- **Master-data exposure and filtering:** PR #11, merged as commit `3e539a4`. Master datasets use an explicit global/scoped policy; scoped rows require matching ULP/UP3/UIW ownership, and unresolved or unclassified scoped datasets fail closed.
- **iOS permissions and privacy configuration:** PR #12, merged as commit `0a474c8`. Camera, location-when-in-use, and photo-library usage descriptions are declared without background location or background modes. Physical-device denied-permission and release-build validation remain pending.
- **Mobile/backend release hardening:** PR #14, merged as commit `fc031c2`. Android release signing fails closed when configuration is missing, release minification/resource shrinking is enabled, backup and cleartext traffic are disabled, and CI verifies signing material, analysis, tests, and debug artifact build.

No production data, secrets, or deployment changes were made by these P2 source remediations.

## Remaining P2 and operational validation

Open follow-up work remains:

- Staging-only fault injection for Sheet, Drive, lock, crash, and timeout scenarios.
- Physical-device validation for iOS denied permissions and signed release configuration.
- Real-device session, restart, offline, backup/restore, and account-switch testing.
- Production provisioning and verification for REL-03 and SEC-06 remain separate from source completion.
- A signed release APK and final artifact inspection remain manual because CI intentionally builds a debug APK only.

## Next audit scope

Source hardening through Task 5 is complete. The next work is operational validation, starting with **Task 6: operational resilience and fault injection**.

Production verification remains separate from source completion. No production sign-off is implied by this addendum.
