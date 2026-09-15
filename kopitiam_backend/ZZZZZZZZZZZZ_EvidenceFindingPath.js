/* Final Folder Path builder for every newly created finding.
 * The WO code is deliberately excluded: all evidence is keyed by Kode Temuan.
 */
var EVIDENCE_MONTH_NAMES_ID_ = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

function evidenceDateText_(dateValue) {
  var date = dateValue instanceof Date ? dateValue : new Date(dateValue);
  if (isNaN(date.getTime())) evidenceFail_('FINDING_DATE_INVALID', 'Tanggal Temuan tidak valid untuk Folder Path.');
  var zone = Session.getScriptTimeZone();
  var day = Utilities.formatDate(date, zone, 'dd');
  var month = Number(Utilities.formatDate(date, zone, 'MM'));
  var year = Utilities.formatDate(date, zone, 'yyyy');
  return day + ' ' + EVIDENCE_MONTH_NAMES_ID_[month - 1] + ' ' + year;
}

function buildFindingPath_(kodeUlp, object, kodeWo, kodeTemuan, now) {
  return evidenceCanonicalPath_(kodeUlp, object, evidenceDateText_(now), kodeTemuan);
}

function buildC4aFindingPath_(kodeUlp, object, kodeTemuan, now) {
  return evidenceCanonicalPath_(kodeUlp, object, evidenceDateText_(now), kodeTemuan);
}
