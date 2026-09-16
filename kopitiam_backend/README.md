# Kopitiam backend: runtime dan alur sistem

## Kontrak perubahan

Konsolidasi ini mempertahankan nama dan parameter seluruh fungsi global, termasuk entry point publik, handler trigger, helper editor, dan handler legacy yang belum terbukti aman dihapus. Tidak ada perubahan UI mobile atau keputusan bisnis. Yang berubah: deployment hanya memuat satu implementasi untuk setiap nama fungsi, dipilih eksplisit melalui `runtime-manifest.json`, bukan prioritas huruf Z.

## Baseline dan status

Baseline main saat pekerjaan dimulai: `bf068bf6b4413d105704255a039db7653623f477` (PR #25). REL-07 berada dalam PR #26, belum menjadi klaim produksi aman. PRD utama tetap `../docs/PRD.md`; perbedaan kebutuhan PRD dengan perilaku source tidak diubah sepihak oleh konsolidator.

## Alur yang dipertahankan

1. Flutter menyimpan pekerjaan dan foto lokal untuk operasional offline.
2. HTTPS POST masuk ke satu `doPost`; GET hanya health.
3. Router memeriksa quota, sesi live, dan otorisasi sebelum dispatch. Handler modul tetap memeriksa hak objek.
4. Insjar memakai WO_Ins_Jar; Insdu memakai WO_Ins_Du. Temuan ber-WO diselesaikan melalui resolver parent; C4A tetap jalur tanpa WO.
5. ROW/Har mengirim WO berfoto per request melalui alur yang sudah disepakati. Backend memvalidasi target, field, folder dan foto.
6. Root Eviden diambil dari Script Property EVIDENCE_ROOT_FOLDER_ID. Folder kanonik berakhir pada Kode Temuan; koreksi path mengikuti guard yang ada.
7. Proposal REL-07 mencatat snapshot dan jurnal, mengklaim lease, menjalankan handler, memverifikasi hasil, lalu menyimpan receipt. Rekonsiliasi bisnis masih menggunakan sesi live pengguna. Trigger hanya pemulihan lease macet dan retensi.
8. Mobile tidak diberi izin baru untuk menghapus pekerjaan hanya karena snapshot diterima. Kontrak receipt committed yang ada tetap berlaku; durable inbox terkelola dan receipt accepted masih rancangan terpisah.

## Build dan deployment

Dari direktori ini, jalankan `npm ci`, `npm run check`, lalu `npm test`. Build memakai Acorn untuk memetakan deklarasi top-level dari daftar source eksplisit. Delapan belas kelompok nama ganda dipilih menurut manifest. Semua nama fungsi tetap ada, sedangkan body deklarasi yang tidak terpilih tidak masuk output.

Output deployment: `deploy/Runtime.js` dan `deploy/appsscript.json`. `.clasp.json` menunjuk rootDir deploy. `runtime-report.json` di luar direktori deployment mencatat asal fungsi dan hash source/runtime untuk audit. Jangan mengunggah source tingkat atas atau menyalin patch Z langsung ke editor. Sebelum push, periksa `clasp status`: hanya Runtime.js dan appsscript.json yang boleh masuk.

Push/deploy produksi tidak dijalankan oleh perubahan PR ini. Sebelum deployment pertama bundle, ambil backup source Apps Script aktif dan inventaris trigger/external caller, cocokkan semua nama handler dengan laporan build, lalu lakukan uji staging. Jangan rollback ke source tanpa guard keamanan.

## Entry point dan trigger

`doGet`, `doPost`, `setupBackend`, `bersihkanTokenPerangkatKedaluwarsa`, `setupOperationJournalTriggers_`, `operationJournalScheduledMaintenance_`, `operationJournalScheduledArchive_`, serta helper editor yang ada tetap didefinisikan. Fungsi test editor tetap dipertahankan untuk kompatibilitas, tetapi jangan dijalankan sebagai health check karena dapat menulis/menghapus data. Lihat DEPLOY.md untuk konfigurasi dan pemasangan trigger; pemasangan tidak otomatis terjadi saat build.

## Kriteria verifikasi

- Build gagal bila ada nama fungsi ganda baru tanpa pemilik eksplisit, pemilik hilang, file source tidak terdaftar, atau variable menimpa fungsi.
- Bundle diparse kembali untuk membuktikan satu deklarasi per nama dan tidak ada nama fungsi yang hilang.
- Tes memuat seluruh runtime bersama, membandingkan body setiap fungsi dengan pemilik terpilih, memeriksa entry point dan menolak receipt terminal rusak.
- Tes fixture membuktikan pemilihan fungsi tidak bergantung urutan input. Ini bukan bukti seluruh perilaku produksi atau seluruh fault injection Sheet/Drive telah lulus.

## Batas konsolidasi

Source patch lama tetap berada di Git untuk keterlacakan, tetapi deklarasi shadow tidak dikirim ke Apps Script. Ini konsolidasi runtime build, bukan penghapusan fisik semua file lama. Tidak ada eliminasi fungsi unik berdasarkan dugaan dead code. Perapian source selanjutnya dapat memindahkan implementasi terpilih ke modul fisik setelah pemanggil eksternal terverifikasi.

Konsolidasi tidak memperbaiki otomatis kelemahan logika fungsi terpilih: validasi header Temuan, identitas jurnal Temuan ber-WO, pengikatan foto ke operation ID, atomic commit jurnal, race lease/retensi, dan otorisasi replay masih memerlukan audit perilaku. Jangan menandai REL-07 selesai hanya karena build dan CI hijau.
