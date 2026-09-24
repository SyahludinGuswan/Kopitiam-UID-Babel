# Auth STAGING: create one smoke-test user

This is an editor-only helper for the isolated **Auth STAGING** project. The helper lives under `kopitiam_auth/staging-only/` and is excluded from ordinary `clasp push` by `kopitiam_auth/.claspignore`. Do not copy it into production or expose it through a web endpoint.

## Prepare the Auth STAGING project

1. Open the separate **Auth STAGING** Apps Script project, not the production Auth project.
2. In **Project Settings → Script Properties**, confirm `AUTH_SPREADSHEET_ID` points to the empty staging `Credentials` spreadsheet. Add `AUTH_ENVIRONMENT` = `STAGING` and `AUTH_STAGING_SPREADSHEET_ID` = the exact same staging spreadsheet ID.
3. Add `STAGING_TEST_USERNAME` with a value like `staging.smoke`. It must start with `staging.`. Add `STAGING_TEST_PASSWORD` with a unique password of at least 12 characters. Do not paste it into chat or commit it.
4. Open `kopitiam_auth/staging-only/Provisioning.js` from the repository, copy its contents, then in the Auth STAGING Apps Script editor add a new script file named `StagingProvisioning` and paste the code. This helper is deliberately not synced by normal `clasp push`.
5. Save, choose `provisionStagingTestCredential_` in the function selector, and click **Run**. Grant the requested authorization if prompted. The function creates one active row with a salted PBKDF2 hash, never stores the plaintext password in the sheet, refuses duplicates, and deletes the two one-time test input properties after it claims them.
6. Confirm that `Credentials` now has one `staging.*` user and the hash/salt fields populated. Then remove `AUTH_ENVIRONMENT` and `AUTH_STAGING_SPREADSHEET_ID` from Auth STAGING Script Properties and delete the temporary helper file from the editor. Keep the test password only in your password manager.

The guard requires the explicit `STAGING` marker and an exact match between the configured staging spreadsheet ID and `AUTH_SPREADSHEET_ID`. The production Apps Script project must not receive these marker properties or the helper file. This step does not require a web-app redeploy.
