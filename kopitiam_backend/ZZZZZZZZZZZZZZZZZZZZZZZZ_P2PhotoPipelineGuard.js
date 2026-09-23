// P2 photo pipeline guards. Loaded after legacy handlers by the runtime manifest.
function p2PhotoUploadRequired_(folderPath, code, base64Data, role) {
  var uploaded = uploadWoPhoto_(folderPath, code, base64Data, role);
  if (!uploaded || !uploaded.file || !uploaded.url || !uploaded.name) throw new Error("PHOTO_UPLOAD_FAILED");
  return uploaded;
}

WO_CORE_MUTABLE.insdu[WO_CORE_MUTABLE.insdu.indexOf("tegangan t-r (v) wbp")] = "tegangan r-t (v) wbp";
