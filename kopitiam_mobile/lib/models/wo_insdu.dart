class WoInsdu {
  static const statusMulai = 'Mulai Pengerjaan';
  static const statusDalam = 'Dalam Pengerjaan';
  static const statusSelesai = 'Selesai';

  final int? id;
  final String no, kodeWo, kodeUiw, kodeUp3, kodeUlp, ulp, hari, tanggal;
  final String penyulang, section, nomorGardu, koordinatGardu, lat, long, jurusan;
  final int? jurusanTerpasang, jurusanTerpakai;
  final double? bebanUtamaRWbp, bebanUtamaSWbp, bebanUtamaTWbp, bebanJurusanNWbp;
  final double? teganganRswbp, teganganStwbp, teganganRtwbp, teganganRnwbp, teganganSnwbp, teganganTnwbp;
  final double? bebanUtamaRLwbp, bebanUtamaSLwbp, bebanUtamaTLwbp, bebanJurusanNLwbp;
  final double? teganganRslwbp, teganganStlwbp, teganganRtlwbp, teganganRnlwbp, teganganSnlwbp, teganganTnlwbp;
  final String koordinatPenginputanWbp, waktuPenginputanWbp, koordinatPenginputanLwbp, waktuPenginputanLwbp;
  final double? jarakGarduPetugasWbp, jarakGarduPetugasLwbp;
  final String coverFcoAtas, coverFcoBawah, coverBushingTm, coverBushingTr, coverArrester, jumperanAtas, jumperanBawah;
  final String waktuMulai, waktuSelesai, durasiPekerjaan, statusWo;
  final bool isDirty;

  const WoInsdu({
    this.id, this.no = '', required this.kodeWo, this.kodeUiw = '', this.kodeUp3 = '', this.kodeUlp = '', this.ulp = '',
    this.hari = '', this.tanggal = '', this.penyulang = '', this.section = '', this.nomorGardu = '', this.koordinatGardu = '',
    this.lat = '', this.long = '', this.jurusan = '', this.jurusanTerpasang, this.jurusanTerpakai,
    this.bebanUtamaRWbp, this.bebanUtamaSWbp, this.bebanUtamaTWbp, this.bebanJurusanNWbp,
    this.teganganRswbp, this.teganganStwbp, this.teganganRtwbp, this.teganganRnwbp, this.teganganSnwbp, this.teganganTnwbp,
    this.bebanUtamaRLwbp, this.bebanUtamaSLwbp, this.bebanUtamaTLwbp, this.bebanJurusanNLwbp,
    this.teganganRslwbp, this.teganganStlwbp, this.teganganRtlwbp, this.teganganRnlwbp, this.teganganSnlwbp, this.teganganTnlwbp,
    this.koordinatPenginputanWbp = '', this.waktuPenginputanWbp = '', this.jarakGarduPetugasWbp,
    this.koordinatPenginputanLwbp = '', this.waktuPenginputanLwbp = '', this.jarakGarduPetugasLwbp,
    this.coverFcoAtas = '', this.coverFcoBawah = '', this.coverBushingTm = '', this.coverBushingTr = '', this.coverArrester = '',
    this.jumperanAtas = '', this.jumperanBawah = '', this.waktuMulai = '', this.waktuSelesai = '', this.durasiPekerjaan = '',
    this.statusWo = statusMulai, this.isDirty = false,
  });

  static String _s(Object? value) => '${value ?? ''}';
  static double? _n(Object? value) => value == null || '$value'.trim().isEmpty ? null : double.tryParse('$value'.replaceAll(',', '.'));
  static int? _i(Object? value) => value == null || '$value'.trim().isEmpty ? null : int.tryParse('$value'.split('.').first);
  static String normalisasiStatus(Object? value) { final s = _s(value).trim().toLowerCase(); if (s == 'selesai') return statusSelesai; if (s.contains('dalam') || s == 'progress' || s == 'berjalan') return statusDalam; return statusMulai; }
  static String _pick(Map<String, dynamic> map, List<String> keys) { for (final key in keys) { final value = _s(map[key]).trim(); if (value.isNotEmpty) return value; } return ''; }
  static double? _pickNum(Map<String, dynamic> map, List<String> keys) => _n(_pick(map, keys));

  factory WoInsdu.fromMap(Map<String, Object?> m) => WoInsdu(
    id: m['id'] as int?, no: _s(m['no']), kodeWo: _s(m['kode_wo']), kodeUiw: _s(m['kode_uiw']), kodeUp3: _s(m['kode_up3']),
    kodeUlp: _s(m['kode_ulp']), ulp: _s(m['ulp']), hari: _s(m['hari']), tanggal: _s(m['tanggal']), penyulang: _s(m['penyulang']),
    section: _s(m['section']), nomorGardu: _s(m['nomor_gardu']), koordinatGardu: _s(m['koordinat_gardu']), lat: _s(m['lat']), long: _s(m['long']),
    jurusan: _s(m['jurusan']), jurusanTerpasang: _i(m['jurusan_terpasang']), jurusanTerpakai: _i(m['jurusan_terpakai']),
    bebanUtamaRWbp: _n(m['beban_utama_r_wbp']), bebanUtamaSWbp: _n(m['beban_utama_s_wbp']), bebanUtamaTWbp: _n(m['beban_utama_t_wbp']), bebanJurusanNWbp: _n(m['beban_jurusan_n_wbp']),
    teganganRswbp: _n(m['tegangan_rs_wbp']), teganganStwbp: _n(m['tegangan_st_wbp']), teganganRtwbp: _n(m['tegangan_rt_wbp']), teganganRnwbp: _n(m['tegangan_rn_wbp']), teganganSnwbp: _n(m['tegangan_sn_wbp']), teganganTnwbp: _n(m['tegangan_tn_wbp']),
    bebanUtamaRLwbp: _n(m['beban_utama_r_lwbp']), bebanUtamaSLwbp: _n(m['beban_utama_s_lwbp']), bebanUtamaTLwbp: _n(m['beban_utama_t_lwbp']), bebanJurusanNLwbp: _n(m['beban_jurusan_n_lwbp']),
    teganganRslwbp: _n(m['tegangan_rs_lwbp']), teganganStlwbp: _n(m['tegangan_st_lwbp']), teganganRtlwbp: _n(m['tegangan_rt_lwbp']), teganganRnlwbp: _n(m['tegangan_rn_lwbp']), teganganSnlwbp: _n(m['tegangan_sn_lwbp']), teganganTnlwbp: _n(m['tegangan_tn_lwbp']),
    koordinatPenginputanWbp: _s(m['koordinat_penginputan_wbp']), waktuPenginputanWbp: _s(m['waktu_penginputan_wbp']), jarakGarduPetugasWbp: _n(m['jarak_gardu_petugas_wbp']),
    koordinatPenginputanLwbp: _s(m['koordinat_penginputan_lwbp']), waktuPenginputanLwbp: _s(m['waktu_penginputan_lwbp']), jarakGarduPetugasLwbp: _n(m['jarak_gardu_petugas_lwbp']),
    coverFcoAtas: _s(m['cover_fco_atas']), coverFcoBawah: _s(m['cover_fco_bawah']), coverBushingTm: _s(m['cover_bushing_tm']), coverBushingTr: _s(m['cover_bushing_tr']), coverArrester: _s(m['cover_arrester']), jumperanAtas: _s(m['jumperan_atas']), jumperanBawah: _s(m['jumperan_bawah']),
    waktuMulai: _s(m['waktu_mulai']), waktuSelesai: _s(m['waktu_selesai']), durasiPekerjaan: _s(m['durasi_pekerjaan']), statusWo: normalisasiStatus(m['status_wo']), isDirty: m['is_dirty'] == 1,
  );

  factory WoInsdu.fromRemote(Map<String, dynamic> m) { double? n(List<String> keys) => _pickNum(m, keys); return WoInsdu(
    no: _pick(m, ['No']), kodeWo: _pick(m, ['Kode WO']), kodeUiw: _pick(m, ['Kode UIW']), kodeUp3: _pick(m, ['Kode UP3']), kodeUlp: _pick(m, ['Kode ULP']), ulp: _pick(m, ['ULP']), hari: _pick(m, ['Hari']), tanggal: _pick(m, ['Tanggal']), penyulang: _pick(m, ['Penyulang']), section: _pick(m, ['Section']), nomorGardu: _pick(m, ['Nomor Gardu']), koordinatGardu: _pick(m, ['Koordinat Gardu']), lat: _pick(m, ['Lat']), long: _pick(m, ['Long']), jurusan: _pick(m, ['Jurusan']), jurusanTerpasang: _i(_pick(m, ['Jurusan Terpasang'])), jurusanTerpakai: _i(_pick(m, ['Jurusan Terpakai'])),
    bebanUtamaRWbp: n(['Beban Utama R (A) WBP']), bebanUtamaSWbp: n(['Beban Utama S (A) WBP']), bebanUtamaTWbp: n(['Beban Utama T (A) WBP']), bebanJurusanNWbp: n(['Beban Jurusan N (A) WBP']), teganganRswbp: n(['Tegangan R-S (V) WBP']), teganganStwbp: n(['Tegangan S-T (V) WBP']), teganganRtwbp: n(['Tegangan R-T (V) WBP']), teganganRnwbp: n(['Tegangan R-N (V) WBP']), teganganSnwbp: n(['Tegangan S-N (V) WBP']), teganganTnwbp: n(['Tegangan T-N (V) WBP']),
    bebanUtamaRLwbp: n(['Beban Utama R (A) LWBP']), bebanUtamaSLwbp: n(['Beban Utama S (A) LWBP']), bebanUtamaTLwbp: n(['Beban Utama T (A) LWBP']), bebanJurusanNLwbp: n(['Beban Jurusan N (A) LWBP']), teganganRslwbp: n(['Tegangan R-S (V) LWBP']), teganganStlwbp: n(['Tegangan S-T (V) LWBP']), teganganRtlwbp: n(['Tegangan R-T (V) LWBP']), teganganRnlwbp: n(['Tegangan R-N (V) LWBP']), teganganSnlwbp: n(['Tegangan S-N (V) LWBP']), teganganTnlwbp: n(['Tegangan T-N (V) LWBP']),
    koordinatPenginputanWbp: _pick(m, ['Koordinat Penginputan WBP']), waktuPenginputanWbp: _pick(m, ['Waktu Penginputan WBP']), jarakGarduPetugasWbp: n(['Jarak Antar Gardu ke Petugas (WBP)']), koordinatPenginputanLwbp: _pick(m, ['Koordinat Penginputan LWBP']), waktuPenginputanLwbp: _pick(m, ['Waktu Penginputan LWBP']), jarakGarduPetugasLwbp: n(['Jarak Antar Gardu ke Petugas (LWBP)']),
    coverFcoAtas: _pick(m, ['Cover Fco Atas']), coverFcoBawah: _pick(m, ['Cover Fco Bawah']), coverBushingTm: _pick(m, ['Cover Bushing TM']), coverBushingTr: _pick(m, ['Cover Bushing TR']), coverArrester: _pick(m, ['Cover Arrester']), jumperanAtas: _pick(m, ['Jumperan Atas']), jumperanBawah: _pick(m, ['Jumperan Bawah']), waktuMulai: _pick(m, ['Waktu Mulai']), waktuSelesai: _pick(m, ['Waktu Selesai']), durasiPekerjaan: _pick(m, ['Durasi Pekerjaan']), statusWo: normalisasiStatus(m['Status WO']),
  ); }

  Map<String, Object?> toMap() => {
    'id': id, 'no': no, 'kode_wo': kodeWo, 'kode_uiw': kodeUiw, 'kode_up3': kodeUp3, 'kode_ulp': kodeUlp, 'ulp': ulp, 'hari': hari, 'tanggal': tanggal, 'penyulang': penyulang, 'section': section, 'nomor_gardu': nomorGardu, 'koordinat_gardu': koordinatGardu, 'lat': lat, 'long': long, 'jurusan': jurusan, 'jurusan_terpasang': jurusanTerpasang, 'jurusan_terpakai': jurusanTerpakai,
    'beban_utama_r_wbp': bebanUtamaRWbp, 'beban_utama_s_wbp': bebanUtamaSWbp, 'beban_utama_t_wbp': bebanUtamaTWbp, 'beban_jurusan_n_wbp': bebanJurusanNWbp, 'tegangan_rs_wbp': teganganRswbp, 'tegangan_st_wbp': teganganStwbp, 'tegangan_rt_wbp': teganganRtwbp, 'tegangan_rn_wbp': teganganRnwbp, 'tegangan_sn_wbp': teganganSnwbp, 'tegangan_tn_wbp': teganganTnwbp,
    'beban_utama_r_lwbp': bebanUtamaRLwbp, 'beban_utama_s_lwbp': bebanUtamaSLwbp, 'beban_utama_t_lwbp': bebanUtamaTLwbp, 'beban_jurusan_n_lwbp': bebanJurusanNLwbp, 'tegangan_rs_lwbp': teganganRslwbp, 'tegangan_st_lwbp': teganganStlwbp, 'tegangan_rt_lwbp': teganganRtlwbp, 'tegangan_rn_lwbp': teganganRnlwbp, 'tegangan_sn_lwbp': teganganSnlwbp, 'tegangan_tn_lwbp': teganganTnlwbp,
    'koordinat_penginputan_wbp': koordinatPenginputanWbp, 'waktu_penginputan_wbp': waktuPenginputanWbp, 'jarak_gardu_petugas_wbp': jarakGarduPetugasWbp, 'koordinat_penginputan_lwbp': koordinatPenginputanLwbp, 'waktu_penginputan_lwbp': waktuPenginputanLwbp, 'jarak_gardu_petugas_lwbp': jarakGarduPetugasLwbp,
    'cover_fco_atas': coverFcoAtas, 'cover_fco_bawah': coverFcoBawah, 'cover_bushing_tm': coverBushingTm, 'cover_bushing_tr': coverBushingTr, 'cover_arrester': coverArrester, 'jumperan_atas': jumperanAtas, 'jumperan_bawah': jumperanBawah, 'waktu_mulai': waktuMulai, 'waktu_selesai': waktuSelesai, 'durasi_pekerjaan': durasiPekerjaan, 'status_wo': statusWo, 'is_dirty': isDirty ? 1 : 0,
  };

  Map<String, dynamic> toRemote() => {
    'Kode WO': kodeWo, 'Kode UIW': kodeUiw, 'Kode UP3': kodeUp3, 'Kode ULP': kodeUlp, 'ULP': ulp, 'Hari': hari, 'Tanggal': tanggal, 'Penyulang': penyulang, 'Section': section, 'Nomor Gardu': nomorGardu, 'Koordinat Gardu': koordinatGardu, 'Lat': lat, 'Long': long, 'Jurusan': jurusan, 'Jurusan Terpasang': jurusanTerpasang, 'Jurusan Terpakai': jurusanTerpakai,
    'Beban Utama R (A) WBP': bebanUtamaRWbp, 'Beban Utama S (A) WBP': bebanUtamaSWbp, 'Beban Utama T (A) WBP': bebanUtamaTWbp, 'Beban Jurusan N (A) WBP': bebanJurusanNWbp, 'Tegangan R-S (V) WBP': teganganRswbp, 'Tegangan S-T (V) WBP': teganganStwbp, 'Tegangan R-T (V) WBP': teganganRtwbp, 'Tegangan R-N (V) WBP': teganganRnwbp, 'Tegangan S-N (V) WBP': teganganSnwbp, 'Tegangan T-N (V) WBP': teganganTnwbp,
    'Beban Utama R (A) LWBP': bebanUtamaRLwbp, 'Beban Utama S (A) LWBP': bebanUtamaSLwbp, 'Beban Utama T (A) LWBP': bebanUtamaTLwbp, 'Beban Jurusan N (A) LWBP': bebanJurusanNLwbp, 'Tegangan R-S (V) LWBP': teganganRslwbp, 'Tegangan S-T (V) LWBP': teganganStlwbp, 'Tegangan R-T (V) LWBP': teganganRtlwbp, 'Tegangan R-N (V) LWBP': teganganRnlwbp, 'Tegangan S-N (V) LWBP': teganganSnlwbp, 'Tegangan T-N (V) LWBP': teganganTnlwbp,
    'Koordinat Penginputan WBP': koordinatPenginputanWbp, 'Waktu Penginputan WBP': waktuPenginputanWbp, 'Jarak Antar Gardu ke Petugas (WBP)': jarakGarduPetugasWbp, 'Koordinat Penginputan LWBP': koordinatPenginputanLwbp, 'Waktu Penginputan LWBP': waktuPenginputanLwbp, 'Jarak Antar Gardu ke Petugas (LWBP)': jarakGarduPetugasLwbp,
    'Cover Fco Atas': coverFcoAtas, 'Cover Fco Bawah': coverFcoBawah, 'Cover Bushing TM': coverBushingTm, 'Cover Bushing TR': coverBushingTr, 'Cover Arrester': coverArrester, 'Jumperan Atas': jumperanAtas, 'Jumperan Bawah': jumperanBawah, 'Waktu Mulai': waktuMulai, 'Waktu Selesai': waktuSelesai, 'Durasi Pekerjaan': durasiPekerjaan, 'Status WO': statusWo,
  };
}
