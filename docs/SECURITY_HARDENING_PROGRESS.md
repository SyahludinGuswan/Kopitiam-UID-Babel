# Audit dan Progress Penguatan Sistem Kopitiam

**Diperbarui:** 16 September 2026  
**Repository:** `gumee08/Kopitiam`  
**Status umum:** penguatan source berlangsung bertahap; deployment dan verifikasi produksi belum dilakukan.

## Tujuan

Dokumen ini merangkum tindak lanjut audit keamanan dan ketahanan Kopitiam pada backend Google Apps Script dan aplikasi Flutter. Perubahan diprioritaskan untuk mencegah akses lintas konteks, kehilangan data lokal, ACK sukses palsu, duplikasi sinkronisasi, serta inkonsistensi antara Google Sheets dan Google Drive tanpa mengubah alur bisnis petugas.

## Prinsip yang dipertahankan

- Aplikasi tetap offline-first dan menyimpan pekerjaan, foto, serta antrean pada perangkat.
- Backend tetap menjadi sumber keputusan otorisasi, validasi, dan commit.
- Mobile hanya menghapus data lokal setelah receipt `committed` cocok dengan snapshot yang dikirim.
- Insjar dan Insdu tidak diwajibkan memiliki foto; ROW dan Har selesai wajib memiliki foto; Har progress boleh tanpa foto.
- Target WO harus cocok berdasarkan Kode WO, ULP, dan tanggal pada baris yang sama.
- Foto disimpan di bawah root Eviden dengan path kanonik dari data pusat.
- Status selesai di source tidak sama dengan deployed atau terverifikasi produksi.

## Selesai di source

| ID | Penguatan | PR | Hasil |
|---|---|---|---|
| SEC-01 | Menutup bypass kepemilikan pada jalur Har legacy | [#13](https://github.com/gumee08/Kopitiam/pull/13) | Target write diverifikasi dengan Kode WO, ULP, dan tanggal yang sama. |
| REL-01 | Mencegah ACK ketika foto atau write belum terverifikasi | [#14](https://github.com/gumee08/Kopitiam/pull/14) | Sheet dan Drive dibaca ulang sebelum receipt sukses. |
| REL-02 | Melengkapi kontrak Insdu | [#15](https://github.com/gumee08/Kopitiam/pull/15) | Field, pengukuran, koordinat, kapasitas, dan validasi Insdu disejajarkan. |
| SEC-02 | Mencabut akses sesi ketika profil pusat berubah | [#17](https://github.com/gumee08/Kopitiam/pull/17) | Role, unit, tim, status, dan akses diperiksa terhadap profil live. |
| SEC-03 | Mengikat quota ke principal terverifikasi | [#18](https://github.com/gumee08/Kopitiam/pull/18), [#19](https://github.com/gumee08/Kopitiam/pull/19) | Quota global atomik, backoff, serialisasi, dan bucket akun live. |
| REL-04 | Receipt immutable sebelum penghapusan lokal | [#22](https://github.com/gumee08/Kopitiam/pull/22) | Receipt harus cocok dengan identitas, payload, dan foto yang dikirim. |
| SEC-09 | Membatasi tujuan upload ke root Eviden | [#23](https://github.com/gumee08/Kopitiam/pull/23) | Path kanonik diturunkan dari Temuan pusat dan parent folder diverifikasi. |
| REL-05 | Membatasi payload sinkronisasi foto | [#24](https://github.com/gumee08/Kopitiam/pull/24) | Satu WO berfoto per request, batas JSON 12 MiB, retry per objek. |
| REL-06 | Memperbaiki resolver parent Temuan Gardu/Jaringan | [#25](https://github.com/gumee08/Kopitiam/pull/25) | Jaringan memakai `WO_Ins_Jar`, Gardu memakai `WO_Ins_Du`. |
| REL-07 | Jurnal operasi durable dan rekonsiliasi | [#26](https://github.com/gumee08/Kopitiam/pull/26) | Lease, checksum, replay receipt, rekonsiliasi, retensi, dan fault-injection guard. |
| REL-09 | Runtime Apps Script deterministik | [#26](https://github.com/gumee08/Kopitiam/pull/26) | Satu `Runtime.js`, 218 fungsi unik, 21 kelompok override dengan pemilik eksplisit. |
| REL-08 | Baseline database lokal bersih | [#27](https://github.com/gumee08/Kopitiam/pull/27) | `kopitiam_local.db` memakai schema transaksional v1; kolom Insjar/Insdu terkini tersedia sejak pembuatan database dan repository tidak lagi memutasi schema saat dibuka. |

PR #26 sudah masuk `main` melalui [commit a66a422](https://github.com/gumee08/Kopitiam/commit/a66a422c430129a3b4236f7928b4f2150d2dcb4f). Audit pascamerge memastikan manifest, guard REL-07, finalizer lock-safe, test, README, dan PRD ikut masuk.

PR #27 sudah masuk `main` melalui [commit c501af1](https://github.com/gumee08/Kopitiam/commit/c501af1842f15b3b684a3a57677052c17e4e753c). Audit pascamerge memverifikasi nama database `kopitiam_local.db`, baseline schema transaksional v1, seluruh kolom Insjar/Insdu pada schema awal, serta tidak adanya mutasi schema saat repository Insjar/Insdu dibuka.

## Temuan terbuka berikutnya

Prioritas P1 yang belum selesai mencakup:

1. SEC-04: rotasi upload key yang pernah tersimpan di source/Git history dan verifikasi secret store rilis; source remediation tersedia tetapi produksi belum tervalidasi.
2. SEC-05: source remediation memindahkan token, profil sesi, dan status offline dari SharedPreferences ke secure storage; review, merge, dan uji perangkat nyata masih wajib.
3. SEC-06: source Auth terpisah tersedia; provisioning, migrasi, dan penghapusan plaintext produksi masih wajib.
4. SEC-07: source remediation menempatkan SQLite, master/cache, antrean, dan foto permanen di namespace hash akun terverifikasi. Database/folder global legacy tidak dimigrasikan otomatis dan tidak lagi dibuka karena pemiliknya tidak dapat diverifikasi; uji perangkat nyata pergantian akun masih wajib sebelum status produksi.
5. SEC-08: satukan kebijakan penugasan, status, dan field mutable seluruh WO.
6. SEC-10: tambahkan identitas Temuan immutable global serta verifikasi owner record existing.
7. SEC-11: turunkan Tier, relasi aset, dan prioritas dari sumber pusat.
8. REL-03: hentikan full-row rewrite, pertahankan formula, dan gunakan revision check.

Temuan P2 seperti validasi struktur JPEG, pembatasan master data, pemrosesan foto, permission iOS, dan penguatan CI/release dikerjakan setelah blocker P1 atau ketika menjadi prasyarat rilis.

### SEC-06: Auth terpisah dan migrasi password

`kopitiam_auth` menyimpan hash PBKDF2-HMAC-SHA-256 bersalt, `Auth Version`, perangkat, dan token opaque yang dapat dicabut. Backend operasional hanya mengirim request internal HMAC untuk login, refresh, introspeksi, dan logout; Flutter tetap memanggil backend operasional. Status belum selesai sampai project Auth dan spreadsheet privat diprovision, migrasi tervalidasi, kolom plaintext `Password` operasional dihapus, serta secret HMAC dirotasi.

### SEC-04: Signing Android

Source tidak lagi menyimpan keystore, `key.properties`, atau password signing yang diobfuscate. Gradle meminta empat property signing dari file lokal yang tidak terlacak dan build release gagal tertutup bila konfigurasi tidak lengkap; CI memblokir material signing dan pola obfuscation pada source. Keystore/password yang pernah tercatat dalam riwayat harus dirotasi dan upload key Play Console diperbarui oleh administrator sebelum status produksi dapat diberikan.

### SEC-05: Credential storage mobile

Token perangkat, profil sesi, dan metadata masa berlaku login offline disimpan melalui `flutter_secure_storage`. `SharedPreferences` hanya menghapus key sesi lama saat bootstrap dan tidak boleh membaca atau menulis credential maupun profil sesi. Pengujian perangkat nyata tetap wajib untuk memverifikasi migrasi dari instalasi yang telah memiliki sesi lama serta perilaku logout dan masa berlaku offline.

## Tahap produksi yang masih wajib

Sebelum menyatakan sistem terverifikasi produksi:

- Deploy bundle Apps Script yang sama dengan commit `main`.
- Konfigurasikan Script Properties, termasuk root Eviden.
- Pasang dan inventaris trigger jurnal maintenance serta arsip.
- Jalankan fault injection staging untuk kegagalan Sheet, Drive, lock, crash, dan timeout.
- Cocokkan receipt dengan Sheet dan file Drive aktif.
- Uji aplikasi pada perangkat nyata, jaringan buruk, restart, antrean besar, dan pergantian akun.
- Verifikasi backup, restore, ACL, logging, dan prosedur rollback yang tidak menghidupkan kembali bypass lama.

## Aturan pembaruan dokumen

Setiap temuan hanya ditandai **selesai di source** setelah PR digabung ke `main`, CI relevan lulus, dan hasil merge diaudit. Status **terverifikasi produksi** baru boleh diberikan setelah deployment dan uji operasional aktual tercatat.
