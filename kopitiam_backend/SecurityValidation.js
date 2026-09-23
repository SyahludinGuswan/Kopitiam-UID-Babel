var MIN_JPEG_BYTES = 1024;

/** Mengurai dan memvalidasi koordinat sebelum dipakai backend. */
function validateCoordinate_(value) {
  var text = String(value == null ? "" : value).trim();
  if (!/^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$/.test(text)) throw new Error("Invalid coordinate format");
  var parts = text.split(","), latitude = Number(parts[0].trim()), longitude = Number(parts[1].trim());
  if (!isFinite(latitude) || !isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) throw new Error("Coordinate out of range");
  if (latitude === 0 && longitude === 0) throw new Error("Null Island coordinate rejected");
  return { latitude: latitude, longitude: longitude };
}

/** Memastikan payload adalah JPEG baseline/progressive yang utuh, bukan sekadar magic bytes. */
function validateJpegBytes_(bytes) {
  if (!bytes || typeof bytes.length !== "number" || bytes.length < MIN_JPEG_BYTES) throw new Error("JPEG too small");
  function u_(index) { var value = Number(bytes[index]); return value < 0 ? value + 256 : value; }
  function marker_(index) { return u_(index) === 0xff && u_(index + 1) !== 0xff && u_(index + 1) !== 0x00; }
  if (u_(0) !== 0xff || u_(1) !== 0xd8) throw new Error("Invalid JPEG SOI");
  var position = 2, hasFrame = false, hasScan = false, hasEnd = false;
  while (position < bytes.length) {
    if (u_(position) !== 0xff) throw new Error("Invalid JPEG marker");
    while (position < bytes.length && u_(position) === 0xff) position++;
    if (position >= bytes.length) throw new Error("Truncated JPEG marker");
    var marker = u_(position++);
    if (marker === 0xd9) { hasEnd = true; if (position !== bytes.length) throw new Error("Trailing bytes after JPEG EOI"); break; }
    if (marker === 0xd8) throw new Error("Embedded JPEG SOI");
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (position + 1 >= bytes.length) throw new Error("Truncated JPEG segment");
    var length = (u_(position) << 8) | u_(position + 1);
    if (length < 2 || position + length > bytes.length) throw new Error("Invalid JPEG segment length");
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      if (length < 8) throw new Error("Invalid JPEG frame header");
      hasFrame = true;
    }
    position += length;
    if (marker === 0xda) {
      hasScan = true;
      while (position < bytes.length) {
        if (u_(position) !== 0xff) { position++; continue; }
        var next = u_(position + 1);
        if (next === 0x00) { position += 2; continue; }
        if (next >= 0xd0 && next <= 0xd7) { position += 2; continue; }
        break;
      }
    }
  }
  if (!hasFrame || !hasScan || !hasEnd) throw new Error("Incomplete JPEG structure");
  return true;
}
