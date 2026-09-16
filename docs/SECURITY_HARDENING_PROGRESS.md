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

PR #26 sudah masuk `main` melalui [commit a66a422](https://github.com/gumee08/Kopitiam/commit/a66a422c430129a3b4236f7928b4f2150d2dcb4f). Audit pascamerge memastikan manifest, guard REL-07, finalizer lock-safe, test, README, dan PRD ikut masuk.

## Sedang berjalan

### REL-08: baseline database lokal

[PR #27](https://github.com/gumee08/Kopitiam/pull/27) mengganti nama database dari `simandist_local.db` menjadi `kopitiam_local.db`, membuat baseline schema transaksional v1, memasukkan seluruh kolom terkini langsung pada schema awal, dan menghapus `PRAGMA/ALTER TABLE` ad-hoc dari repository Insjar/Insdu.

Kopitiam belum memiliki data produksi, sehingga baseline baru dipilih daripada mempertahankan rantai migrasi historis yang belum diperlukan. Database lokal tetap wajib untuk WO, draft, foto, master cache, dan antrean offline. CI `analyze-test-build` pada head terbaru sudah lulus; PR masih menunggu review dan merge.

## Temuan terbuka berikutnya

Prioritas P1 yang belum selesai mencakup:

1. SEC-04: keluarkan material signing Android dari source dan siapkan prosedur key yang aman.
2. SEC-05: hapus token sesi/device dari SharedPreferences dan gunakan secure storage sebagai satu-satunya credential store.
3. SEC-06: hentikan ketergantungan pada password plaintext di pusat dan tolak akun nonaktif sebelum penerbitan sesi.
4. SEC-07: pisahkan data, foto, cache, dan antrean lokal per akun.
5. SEC-08: satukan kebijakan penugasan, status, dan field mutable seluruh WO.
6. SEC-10: tambahkan identitas Temuan immutable global serta verifikasi owner record existing.
7. SEC-11: turunkan Tier, relasi aset, dan prioritas dari sumber pusat.
8. REL-03: hentikan full-row rewrite, pertahankan formula, dan gunakan revision check.

Temuan P2 seperti validasi struktur JPEG, pembatasan master data, pemrosesan foto, permission iOS, dan penguatan CI/release dikerjakan setelah blocker P1 atau ketika menjadi prasyarat rilis.

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
