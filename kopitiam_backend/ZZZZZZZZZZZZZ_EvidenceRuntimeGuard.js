/* Runtime guard for the canonical Eviden root, finding date, and photo parents. */
var EVIDENCE_ROOT_PROPERTY_ = 'EVIDENCE_ROOT_FOLDER_ID';
var EVIDENCE_REQUEST_DATE_ = '';

function evidenceRootFolder_() {
  var folderId = String(PropertiesService.getScriptProperties().getProperty(EVIDENCE_ROOT_PROPERTY_) || '').trim();
  if (!/^[A-Za-z0-9_-]{10,}$/.test(folderId)) {
    evidenceFail_('EVIDENCE_ROOT_NOT_CONFIGURED', 'Script Property EVIDENCE_ROOT_FOLDER_ID belum dikonfigurasi.');
  }
  try {
    var folder = DriveApp.getFolderById(folderId);
    if (folder.isTrashed && folder.isTrashed()) {
      evidenceFail_('EVIDENCE_ROOT_INVALID', 'Root Eviden berada di sampah.');
    }
    return folder;
  } catch (error) {
    if (error && error.evidenceCode) throw error;
    evidenceFail_('EVIDENCE_ROOT_UNAVAILABLE', 'Root Eviden tidak dapat diakses oleh akun deployment.');
  }
}

function configureEvidenceRootFolder_(folderId) {
  folderId = String(folderId || '').trim();
  if (!/^[A-Za-z0-9_-]{10,}$/.test(folderId)) throw new Error('Folder ID Eviden tidak valid.');
  var folder = DriveApp.getFolderById(folderId);
  if (folder.isTrashed && folder.isTrashed()) throw new Error('Folder Eviden berada di sampah.');
  PropertiesService.getScriptProperties().setProperty(EVIDENCE_ROOT_PROPERTY_, folderId);
  return { success: true, folderId: folder.getId(), folderName: folder.getName() };
}

function folderPath_(pathValue) {
  var root = evidenceRootFolder_();
  var parts = evidenceRelativePath_(pathValue).split('/').filter(function (part) {
    return String(part).trim() !== '';
  });
  var current = root;
  for (var i = 0; i < parts.length; i++) {
    var name = safePath_(parts[i]);
    var folders = current.getFoldersByName(name);
    var next = folders.hasNext() ? folders.next() : current.createFolder(name);
    if (folders.hasNext()) evidenceFail_('FOLDER_PATH_AMBIGUOUS', 'Ditemukan folder ganda pada segmen: ' + name + '.');
    current = next;
  }
  return current;
}

function evidenceRequestDate_() {
  var value = String(EVIDENCE_REQUEST_DATE_ || '').trim();
  if (!value) evidenceFail_('FINDING_DATE_REQUIRED', 'Tanggal Temuan wajib diisi untuk membentuk Folder Path.');
  /* Parsing by evidenceCanonicalPath_ performs real calendar validation. */
  return value;
}

function buildFindingPath_(kodeUlp, object, kodeWo, kodeTemuan, ignoredNow) {
  return evidenceCanonicalPath_(kodeUlp, object, evidenceRequestDate_(), kodeTemuan);
}

function buildC4aFindingPath_(kodeUlp, object, kodeTemuan, ignoredNow) {
  return evidenceCanonicalPath_(kodeUlp, object, evidenceRequestDate_(), kodeTemuan);
}

function evidenceFileIdFromUrl_(url) {
  var text = String(url || '').trim();
  var match = text.match(/\/d\/([A-Za-z0-9_-]{10,})/) || text.match(/[?&]id=([A-Za-z0-9_-]{10,})/);
  if (!match) evidenceFail_('PHOTO_FILE_ID_INVALID', 'File ID foto tidak dapat dibaca dari respons Drive.');
  return match[1];
}

function evidenceVerifyFileParent_(fileId, expectedFolderId, label) {
  var file;
  try { file = DriveApp.getFileById(fileId); }
  catch (_) { evidenceFail_('PHOTO_FILE_UNAVAILABLE', label + ' tidak dapat dibaca kembali dari Drive.'); }
  var parents = file.getParents();
  var matched = false;
  while (parents.hasNext()) {
    if (parents.next().getId() === expectedFolderId) matched = true;
  }
  if (!matched) evidenceFail_('PHOTO_PARENT_MISMATCH', label + ' tidak berada pada Folder Path kanonik.');
  return { fileId: file.getId(), parentFolderId: expectedFolderId };
}

function evidenceVerifyFindingPhotos_(result, incoming) {
  if (!result || result.success !== true) return result;
  var kodeUlp = String(incoming['Kode ULP'] || '').trim();
  var object = String(incoming['Jenis Object'] || '').trim();
  var code = String(incoming['Kode Temuan'] || '').trim();
  var canonical = evidenceCanonicalPath_(kodeUlp, object, incoming.Tanggal, code);
  var folder = folderPath_(canonical);
  var folderId = folder.getId();
  var primaryId = evidenceFileIdFromUrl_(result.linkFoto);
  var environmentId = evidenceFileIdFromUrl_(result.linkLingkungan);
  result.folderPath = canonical;
  result.photoReceipts = {
    fotoTemuan: evidenceVerifyFileParent_(primaryId, folderId, 'Foto Temuan'),
    fotoLingkungan: evidenceVerifyFileParent_(environmentId, folderId, 'Foto Lingkungan')
  };
  return result;
}

function syncTemuanWithEvidenceGuard_(token, incoming) {
  if (!incoming || typeof incoming !== 'object') return fail_('FINDING_REQUIRED', 'Data temuan kosong.');
  var copy = {};
  Object.keys(incoming).forEach(function (key) { copy[key] = incoming[key]; });
  var previous = EVIDENCE_REQUEST_DATE_;
  try {
    EVIDENCE_REQUEST_DATE_ = String(copy.Tanggal || '').trim();
    /* Validate before upload and ensure retries on another day resolve identically. */
    evidenceCanonicalPath_(copy['Kode ULP'], copy['Jenis Object'], evidenceRequestDate_(), copy['Kode Temuan']);
    return evidenceVerifyFindingPhotos_(syncTemuanInspeksiIdempotent_(token, copy), copy);
  } catch (error) {
    return fail_(error.evidenceCode || 'EVIDENCE_COMMIT_FAILED', error.message);
  } finally {
    EVIDENCE_REQUEST_DATE_ = previous;
  }
}
