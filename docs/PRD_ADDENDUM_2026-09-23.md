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

## Next audit scope

REL-03 is no longer an open audit item. The next source audit is **P2 hardening**, followed by operational validation:

- JPEG structure and content validation.
- Master-data exposure and filtering.
- Photo processing and upload failure handling.
- iOS permissions and release hardening.
- Real-device session, restart, offline, backup/restore, and account-switch tests.
- Staging fault injection for Sheet, Drive, lock, crash, and timeout scenarios.

Production verification remains separate from source completion. No production sign-off is implied by this addendum.
