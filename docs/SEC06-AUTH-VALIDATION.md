# SEC-06 Auth validation

## Source coverage

`kopitiam_auth/AuthService.js` provides PBKDF2-HMAC-SHA-256 password hashing, opaque sessions, device expiry, introspection, revoke, replay protection, and an HMAC-signed internal envelope.

Run the Auth regression suite locally from the repository root:

```powershell
.\ci\run-sec06-auth-tests.ps1
```

The suite must pass before any provisioning or migration work.

## Production blockers

The following are not performed by this repository change:

- provisioning the private Auth spreadsheet and `AUTH_SPREADSHEET_ID`
- provisioning `AUTH_SERVICE_SHARED_SECRET`
- configuring legacy source IDs for migration
- executing `migrateLegacyPlaintextPasswords_`
- verifying migrated accounts and recovery
- removing the legacy `Password` column
- rotating HMAC material in the live environment

Never commit or paste secret values. Production migration requires a backup, a dry run or staging verification, an account-count reconciliation, and a rollback plan before the legacy column is removed.
