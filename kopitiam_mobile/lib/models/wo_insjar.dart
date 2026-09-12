class WoInsjar {
  static const statusMulai = 'Mulai Pengerjaan';
  static const statusDalam = 'Dalam Pengerjaan';
  static const statusSelesai = 'Selesai';
  static const statusValues = [statusMulai, statusDalam, statusSelesai];

  final int? id;
  final String no;
  final String kodeWo;
  final String kodeUiw;
  final String kodeUp3;
  final String kodeUlp;
  final String ulp;
  final String hari;
  final String tanggal;
  final String penyulang;
  final String sectionAwal;
  final String sectionAkhir;
  final String section;
  final String tier;
  final String koordinatAwal;
  final String koordinatAkhir;
  final double? realisasiKms;
  final String waktuMulai;
  final String waktuSelesai;
  final String durasiPekerjaan;
  final String statusWo;
  final bool isDirty;

  const WoInsjar({
    this.id,
    this.no = '',
    required this.kodeWo,
    this.kodeUiw = '',
    this.kodeUp3 = '',
    this.kodeUlp = '',
    this.ulp = '',
    this.hari = '',
    this.tanggal = '',
    this.penyulang = '',
    this.sectionAwal = '',
    this.sectionAkhir = '',
    this.section = '',
    this.tier = '',
    this.koordinatAwal = '',
    this.koordinatAkhir = '',
    this.realisasiKms,
    this.waktuMulai = '',
    this.waktuSelesai = '',
    this.durasiPekerjaan = '',
    this.statusWo = statusMulai,
    this.isDirty = false,
  });

  static const hariIndonesia = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const bulanIndonesia = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  static String normalisasiStatus(Object? value) {
    final status = '${value ?? ''}'.trim().toLowerCase();
    if (status == statusSelesai.toLowerCase()) return statusSelesai;
    if (status == statusDalam.toLowerCase() || status == 'dalam pengerjaan' || status == 'berjalan' || status == 'progress') return statusDalam;
    return statusMulai;
  }

  factory WoInsjar.fromMap(Map<String, Object?> map) => WoInsjar(
    id: map['id'] as int?, no: '${map['no'] ?? ''}', kodeWo: '${map['kode_wo'] ?? ''}',
    kodeUiw: '${map['kode_uiw'] ?? ''}', kodeUp3: '${map['kode_up3'] ?? ''}', kodeUlp: '${map['kode_ulp'] ?? ''}',
    ulp: '${map['ulp'] ?? ''}', hari: '${map['hari'] ?? ''}', tanggal: '${map['tanggal'] ?? ''}',
    penyulang: '${map['penyulang'] ?? ''}', sectionAwal: '${map['section_awal'] ?? ''}', sectionAkhir: '${map['section_akhir'] ?? ''}',
    section: '${map['section'] ?? ''}', tier: '${map['tier'] ?? ''}', koordinatAwal: '${map['koordinat_awal'] ?? ''}',
    koordinatAkhir: '${map['koordinat_akhir'] ?? ''}', realisasiKms: (map['realisasi_kms'] as num?)?.toDouble(),
    waktuMulai: '${map['waktu_mulai'] ?? ''}', waktuSelesai: '${map['waktu_selesai'] ?? ''}',
    durasiPekerjaan: '${map['durasi_pekerjaan'] ?? ''}', statusWo: normalisasiStatus(map['status_wo']), isDirty: map['is_dirty'] == 1,
  );

  factory WoInsjar.fromRemote(Map<String, dynamic> row) {
    String pick(List<String> keys) {
      for (final key in keys) { final value = '${row[key] ?? ''}'.trim(); if (value.isNotEmpty) return value; }
      return '';
    }
    final rawKms = row['Realisasi kmS'] ?? row['realisasiKms'];
    final kmsText = '${rawKms ?? ''}'.replaceAll(',', '.').trim();
    return WoInsjar(
      no: pick(['No','no']), kodeWo: pick(['Kode WO','kodeWo']), kodeUiw: pick(['Kode UIW','kodeUiw']),
      kodeUp3: pick(['Kode UP3','kodeUp3']), kodeUlp: pick(['Kode ULP','kodeUlp']), ulp: pick(['ULP','ulp']),
      hari: pick(['Hari','hari']), tanggal: pick(['Tanggal','tanggal']), penyulang: pick(['Penyulang','penyulang']),
      sectionAwal: pick(['Section Awal','sectionAwal']), sectionAkhir: pick(['Section Akhir','sectionAkhir']),
      section: pick(['Section','section']), tier: pick(['Tier','tier']), koordinatAwal: pick(['Koordinat Awal','koordinatAwal']),
      koordinatAkhir: pick(['Koordinat Akhir','koordinatAkhir']),
      realisasiKms: rawKms is num ? rawKms.toDouble() : (kmsText.isEmpty ? null : double.tryParse(kmsText)),
      waktuMulai: pick(['Waktu Mulai','waktuMulai']), waktuSelesai: pick(['Waktu Selesai','waktuSelesai']),
      durasiPekerjaan: pick(['Durasi Pekerjaan','durasiPekerjaan']), statusWo: normalisasiStatus(row['Status WO'] ?? row['statusWo']),
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'no': no, 'kode_wo': kodeWo, 'kode_uiw': kodeUiw, 'kode_up3': kodeUp3, 'kode_ulp': kodeUlp,
    'ulp': ulp, 'hari': hari, 'tanggal': tanggal, 'penyulang': penyulang,
    'section_awal': sectionAwal, 'section_akhir': sectionAkhir, 'section': section, 'tier': tier,
    'koordinat_awal': koordinatAwal, 'koordinat_akhir': koordinatAkhir, 'realisasi_kms': realisasiKms,
    'waktu_mulai': waktuMulai, 'waktu_selesai': waktuSelesai, 'durasi_pekerjaan': durasiPekerjaan,
    'status_wo': normalisasiStatus(statusWo), 'is_dirty': isDirty ? 1 : 0,
  };

  Map<String, dynamic> toRemote() => {
    'Kode WO': kodeWo, 'Kode UIW': kodeUiw, 'Kode UP3': kodeUp3, 'Kode ULP': kodeUlp, 'ULP': ulp,
    'Hari': hari, 'Tanggal': tanggal, 'Penyulang': penyulang, 'Section Awal': sectionAwal,
    'Section Akhir': sectionAkhir, 'Section': section, 'Tier': tier,
    'Koordinat Awal': koordinatAwal, 'Koordinat Akhir': koordinatAkhir, 'Realisasi kmS': realisasiKms,
    'Waktu Mulai': waktuMulai, 'Waktu Selesai': waktuSelesai, 'Durasi Pekerjaan': durasiPekerjaan,
    'Status WO': normalisasiStatus(statusWo),
  };

  WoInsjar copyWith({String? tier, String? koordinatAwal, String? koordinatAkhir, double? realisasiKms, String? waktuMulai, String? waktuSelesai, String? durasiPekerjaan, String? statusWo, bool? isDirty}) => WoInsjar(
    id:id, no:no, kodeWo:kodeWo, kodeUiw:kodeUiw, kodeUp3:kodeUp3, kodeUlp:kodeUlp, ulp:ulp, hari:hari,
    tanggal:tanggal, penyulang:penyulang, sectionAwal:sectionAwal, sectionAkhir:sectionAkhir, section:section,
    tier:tier ?? this.tier, koordinatAwal:koordinatAwal ?? this.koordinatAwal, koordinatAkhir:koordinatAkhir ?? this.koordinatAkhir,
    realisasiKms:realisasiKms ?? this.realisasiKms, waktuMulai:waktuMulai ?? this.waktuMulai,
    waktuSelesai:waktuSelesai ?? this.waktuSelesai, durasiPekerjaan:durasiPekerjaan ?? this.durasiPekerjaan,
    statusWo:statusWo ?? this.statusWo, isDirty:isDirty ?? this.isDirty,
  );

  static String formatTanggal(DateTime value) => '${value.day.toString().padLeft(2, '0')} ${bulanIndonesia[value.month - 1]} ${value.year}';
  static String stampLengkap(DateTime value) { String two(int input) => input.toString().padLeft(2, '0'); return '${formatTanggal(value)}, ${two(value.hour)}:${two(value.minute)}:${two(value.second)}'; }
  static String hitungDurasi(DateTime mulai, DateTime selesai) { final diff=selesai.difference(mulai); if(diff.isNegative)return '00:00:00'; String two(int input)=>input.toString().padLeft(2,'0'); return '${two(diff.inHours)}:${two(diff.inMinutes%60)}:${two(diff.inSeconds%60)}'; }
  static DateTime? parseStamp(String value) {
    final match=RegExp(r'^(\d{2})\s+([A-Za-z]+)\s+(\d{4}),\s+(\d{2}):(\d{2}):(\d{2})$').firstMatch(value.trim());
    if(match==null)return null;
    final month=bulanIndonesia.map((item)=>item.toLowerCase()).toList().indexOf(match.group(2)!.toLowerCase());
    if(month<0)return null;
    return DateTime(int.parse(match.group(3)!),month+1,int.parse(match.group(1)!),int.parse(match.group(4)!),int.parse(match.group(5)!),int.parse(match.group(6)!));
  }
}
