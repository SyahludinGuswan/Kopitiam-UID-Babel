# PRD Addendum: Integritas Sinkronisasi dan Runtime Backend

Status dokumen: memperjelas alur yang dipertahankan dan target penguatan REL-07. Addendum ini tidak mengubah layar, urutan kerja petugas, field bisnis, atau kebijakan akses yang sudah disepakati pada PRD utama.

## Alur yang tidak boleh berubah

1. Petugas bekerja offline dan menyimpan pekerjaan/foto di perangkat.
2. Sinkronisasi memakai HTTPS POST dan sesi yang masih valid. GET hanya untuk health.
3. Backend memvalidasi principal live, ULP, modul, target WO/Temuan, field, status, Folder Path, serta bukti foto.
4. ROW, Har Jar, dan Har Du memproses satu WO berfoto per request. Insjar/Insdu mengikuti kontrak modul tanpa kewajiban foto yang tidak disepakati.
5. Backend menulis dan membaca ulang Sheet/Drive, lalu menerbitkan receipt committed yang terikat identitas objek, payload digest, dan foto bila relevan.
6. Mobile hanya menghapus data lokal setelah receipt committed cocok. Durable inbox tidak mengubah aturan ini menjadi penghapusan setelah accepted.
7. Kegagalan parsial dipertahankan sebagai prepared/processing/needs-reconciliation dan tidak dianggap sukses.

## Runtime backend deterministik

Deployment dibangun sebagai satu Runtime.js. Setiap fungsi global memiliki satu implementasi terpilih melalui runtime-manifest.json. Build gagal bila ada fungsi ganda baru tanpa keputusan eksplisit, source deployable yang tidak terdaftar, entry point hilang, atau assignment top-level yang menimpa fungsi.

Entry point dan handler yang dipertahankan mencakup doGet, doPost, setupBackend, pembersihan token, setup/maintenance/arsip jurnal, serta helper editor yang sudah ada. Fungsi unik tidak dihapus hanya karena pemanggil internal belum ditemukan.

## Kontrak REL-07

- Operation ID mengikat username live, action, identitas objek kanonik, payload digest, dan digest seluruh foto.
- Untuk Temuan, identitas objek adalah Kode Temuan, bukan Kode WO induk.
- Snapshot durable tidak menyimpan token, device token, atau password; file JSON dan receipt memiliki checksum terpisah.
- Lease mencegah executor ganda. Pelepasan lease macet wajib membaca ulang record di dalam lock agar tidak menimpa state baru.
- Temuan hanya committed bila semua field kiriman memiliki kolom tujuan dan proyeksi nilai Sheet hasil baca ulang sama dengan snapshot.
- Receipt terminal committed/archived/purged yang rusak diblokir, tidak dieksekusi ulang.
- Rekonsiliasi bisnis memakai sesi live pengguna. Trigger tanpa sesi hanya melepaskan lease macet dan menjalankan retensi.
- Retensi: committed/resolved aktif 30 hari, arsip 1 tahun, lalu payload dapat dipurge; record unresolved tidak dihapus otomatis.

## Batas status

PR/CI membuktikan source dan tes mock, bukan deployment produksi. Sebelum menandai REL-07 terverifikasi produksi: deploy bundle yang sama, pasang trigger, validasi Script Properties/root Eviden, uji fault injection staging, dan cocokkan receipt dengan Sheet/Drive aktif.
