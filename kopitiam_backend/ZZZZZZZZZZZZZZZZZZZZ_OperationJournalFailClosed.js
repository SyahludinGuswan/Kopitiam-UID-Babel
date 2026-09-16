/* REL-07 final fail-closed guard: no Drive read under global lock, no terminal re-execution. */
function operationJournalPrepare_(identity, body) {
  var source, found, existing, state;
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    source = operationJournalSheet_();
    found = operationJournalFind_(source, identity.operationId);
    existing = operationJournalObject_(source, found);
    if (existing) {
      if (normalize_(existing['Username']) !== identity.username ||
          String(existing['Payload Digest']).toLowerCase() !== identity.payloadDigest) {
        throw new Error('Operation ID tidak cocok dengan principal atau digest.');
      }
      state = normalize_(existing['State']);
    }
  } finally {
    lock.releaseLock();
  }

  if (existing) {
    if (['committed', 'archived', 'purged'].indexOf(state) >= 0) return existing;
    /* Drive checksum verification intentionally runs after releasing ScriptLock. */
    opjLoadPayloadVerified_(existing);
    return existing;
  }

  var stored = opjStorePayloadOutsideLock_(identity, body);
  if (!stored || !stored.fileId ||
      !/^[a-f0-9]{64}$/i.test(String(stored.digest || ''))) {
    throw new Error('Snapshot durable gagal diverifikasi sebelum pencatatan jurnal.');
  }

  lock = LockService.getScriptLock();
  lock.waitLock(20000);
  var created;
  try {
    source = operationJournalSheet_();
    found = operationJournalFind_(source, identity.operationId);
    existing = operationJournalObject_(source, found);
    if (existing) {
      if (stored.created && String(existing['Payload File ID']) !== stored.fileId) {
        try { DriveApp.getFileById(stored.fileId).setTrashed(true); } catch (_) {}
      }
      created = existing;
    } else {
      var now = operationJournalNow_();
      var row = {
        'Operation ID': identity.operationId,
        'Action': identity.action,
        'Object ID': identity.objectId,
        'Username': identity.username,
        'Payload Digest': identity.payloadDigest,
        'State': 'prepared',
        'Attempt Count': 0,
        'First Prepared At': operationJournalIso_(now),
        'Last Attempt At': '',
        'Committed At': '',
        'Resolved At': '',
        'Receipt JSON': '',
        'Receipt Digest': '',
        'Error Code': '',
        'Error Message': '',
        'Next Reconciliation At': operationJournalIso_(now),
        'Archive After': operationJournalIso_(
          operationJournalAddDays_(now, OPERATION_JOURNAL_ACTIVE_FAILURE_DAYS_)
        ),
        'Payload File ID': stored.fileId,
        'Payload File Digest': String(stored.digest).toLowerCase(),
        'Lease Until': '',
        'Lease Token': '',
        'Archived At': ''
      };
      source.sheet.appendRow(source.headers.map(function (header) {
        return row[header] === undefined ? '' : safeCell_(row[header]);
      }));
      SpreadsheetApp.flush();
      created = operationJournalObject_(
        source,
        operationJournalFind_(source, identity.operationId)
      );
    }
  } finally {
    lock.releaseLock();
  }

  /* Read Drive only after the lock has been released. */
  if (['committed', 'archived', 'purged'].indexOf(normalize_(created['State'])) < 0) {
    opjLoadPayloadVerified_(created);
  }
  return created;
}

function operationJournalRun_(action, body, session, executor) {
  var identity;
  try {
    identity = operationJournalIdentity_(action, body, session);
  } catch (error) {
    return fail_('OPERATION_JOURNAL_INVALID', error.message);
  }

  var record;
  try {
    record = operationJournalPrepare_(identity, body);
  } catch (error) {
    return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message);
  }

  var state = normalize_(record && record['State']);
  var terminal = ['committed', 'archived', 'purged'].indexOf(state) >= 0;
  var replay = operationJournalReplay_(record);
  if (replay) return replay;
  if (terminal) {
    /* Never re-execute a terminal operation if its receipt is missing or corrupt. */
    return fail_(
      'OPERATION_RECEIPT_INTEGRITY_FAILED',
      'Receipt terminal tidak lolos verifikasi checksum; operasi diblokir.'
    );
  }

  var claim;
  try {
    claim = opjClaim_(identity.operationId);
  } catch (error) {
    return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message);
  }
  if (claim.busy) {
    return fail_('OPERATION_IN_PROGRESS', 'Operasi yang sama sedang diproses.');
  }
  if (claim.committed) {
    replay = operationJournalReplay_(claim.record);
    return replay || fail_(
      'OPERATION_RECEIPT_INTEGRITY_FAILED',
      'Receipt committed tidak lolos verifikasi checksum; operasi diblokir.'
    );
  }

  var result;
  try {
    result = executor();
  } catch (error) {
    result = fail_(
      'OPERATION_INTERRUPTED',
      String(error && error.message || error || 'Operasi terputus.')
    );
  }
  var verified = opjVerifiedSuccess_(action, result, identity);
  if (result && result.success === true && !verified) {
    result = fail_(
      'OPERATION_RECEIPT_INVALID',
      'Respons sukses tidak memiliki receipt final yang valid.'
    );
  }
  try {
    opjFinish_(identity.operationId, claim.token, result, verified);
  } catch (error) {
    return fail_('OPERATION_JOURNAL_UNAVAILABLE', error.message);
  }
  if (result && typeof result === 'object') result.operationId = identity.operationId;
  return result;
}
