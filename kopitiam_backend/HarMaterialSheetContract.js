/* Production contract for the HAR material detail sheet. */
function configureHarMaterialSheet_() {
  CONFIG.MATERIAL_HAR_JAR_SHEET = "Material_WO_Har";
  return CONFIG.MATERIAL_HAR_JAR_SHEET;
}

// Exact business-sheet headers. The runtime reader canonicalizes "Kode WO Har"
// to "Kode WO"; setup validates the physical sheet names without rewriting it.
var HAR_MATERIAL_SETUP_HEADERS_ = [
  "No",
  "Kode Penggunaan Material",
  "Kode Pekerjaan",
  "Kode WO Har",
  "Kode Temuan",
  "Kode UIW",
  "Kode UP3",
  "Kode ULP",
  "ULP",
  "Hari",
  "Tanggal",
  "Penyulang",
  "Section",
  "Segmen",
  "Nomor Gardu",
  "Jenis Object",
  "Tier",
  "Temuan",
  "Prioritas",
  "Jenis WO",
  "Koordinat",
  "Lat",
  "Long",
  "Uraian Pekerjaan",
  "Material",
  "Jumlah",
  "Satuan",
  "Kepemilikan",
  "Catatan",
  "User Input",
  "Waktu Input",
];
