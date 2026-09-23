# P2 Operational Resilience Validation Matrix

Status: **staging-only plan and harness coverage**. No production spreadsheet, Drive folder, account, secret, or deployment may be used.

## Rules

- Use a dedicated staging Apps Script deployment, staging spreadsheets, staging Drive root, test accounts, and disposable mobile data.
- Record run ID, commit SHA, environment, injected fault, expected result, actual result, receipt/journal state, logs, and cleanup evidence.
- A scenario passes only when no false success is returned, no partial business commit is left unexplained, retry behavior is bounded/idempotent, and recovery is auditable.
- Stop immediately if a staging identifier resolves to production or if ownership, account, or dataset scope is ambiguous.

## Validation matrix

| ID | Fault or scenario | Injection point | Expected result | Evidence |
|---|---|---|---|---|
| S01 | Sheet read failure | master/WO/Temuan read | fail closed, generic error, no data-dependent success | response, execution log |
| S02 | Sheet write failure | sparse write or journal write | operation is not successful; journal is `needs-reconciliation` or unavailable | response, journal row, log |
| S03 | Spreadsheet flush timeout | post-write flush | no false committed receipt; retry/reconciliation path retained | receipt digest, journal row |
| S04 | Drive upload failure | required photo upload | `PHOTO_UPLOAD_FAILED` or equivalent; no Sheet success commit | response, orphan scan |
| S05 | Drive read-back/digest mismatch | file verification | success rejected; reconciliation retained; mismatch logged | digest comparison, journal |
| S06 | Lock contention | ScriptLock/lease claim | bounded wait or `OPERATION_IN_PROGRESS`; no duplicate commit | concurrent run IDs, journal |
| S07 | Worker crash | executor after claim/before finish | lease becomes recoverable; no replay without verification | stale lease sweep, journal |
| S08 | Network timeout | mobile/backend request | client shows retryable failure; no duplicate business write | client log, operation ID |
| S09 | Duplicate delivery | same operation ID/payload | replay committed receipt or one in-flight response; executor runs once | operation ID, receipts |
| S10 | Restart during pending sync | app restart with outbox | outbox survives; retry is idempotent; account namespace unchanged | outbox dump, receipt |
| S11 | Offline queue | no network during capture | local queue remains bounded and visible; no silent data loss | queue state, UI evidence |
| S12 | Account switch | switch A to B with pending local data | B cannot read A database/photos/outbox; A data returns after switch back | namespace paths, screenshots |
| S13 | Backup/restore | restore staging app data | restored data remains account-scoped; expired session is not revived | storage inventory, auth result |
| S14 | Rollback | deploy previous tested bundle | health passes, writes remain fail-closed if metadata/config mismatches | deployment record, smoke results |

## Exit criteria

- S01-S09 pass in staging with captured journal and logs.
- S10-S13 pass on at least one Android device and one iOS device when available.
- S14 passes using a disposable staging deployment and rollback artifact.
- Any failed or skipped scenario has an owner, blocker, and next action; no production sign-off is implied.

## Current evidence

- Backend fault-injection tests already cover journal creation/attempt/commit failures, Drive and Sheet failure classes, executor crash, and committed replay in `kopitiam_backend/test/operation-journal-fault-injection.test.js`.
- Mobile account namespace isolation is covered by `kopitiam_mobile/test/account_storage_isolation_test.dart`.
- Physical-device execution, staging deployment, and backup/restore evidence are still pending.
