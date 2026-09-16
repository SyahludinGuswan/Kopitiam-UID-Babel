# Deploy Backend Kopitiam

## Konfigurasi wajib SEC-09

Sebelum deploy, jalankan fungsi berikut satu kali dari Apps Script editor menggunakan akun deployment:

```javascript
configureEvidenceRootFolder_('1HAh-FAonWDyXvOEKroQbvu9vi6tlT1iL');
```

Fungsi memvalidasi akses lalu menyimpan ID folder `Eviden` sebagai Script Property `EVIDENCE_ROOT_FOLDER_ID`. Upload akan gagal tertutup jika property hilang, ID salah, folder berada di sampah, atau akun deployment tidak memiliki akses.

## Trigger wajib REL-07

Setelah deployment, jalankan satu kali:

```javascript
setupOperationJournalTriggers_();
```

Fungsi membuat maintenance tiap 15 menit untuk melepaskan lease worker yang macet, serta arsip harian pukul 02.00 zona waktu project. Replay bisnis tetap membutuhkan sesi pengguna yang aktif agar trigger tidak melewati otorisasi.

Jangan memasukkan Folder Path dari mobile sebagai sumber lokasi. Path harus dihitung dari Kode ULP, Jenis Object, Tanggal, dan Kode Temuan pusat.
