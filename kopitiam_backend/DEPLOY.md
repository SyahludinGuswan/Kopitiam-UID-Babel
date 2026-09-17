# Deploy Backend Kopitiam

## Prasyarat SEC-06: layanan Auth privat

Buat project Google Apps Script kedua dari `../kopitiam_auth` dan spreadsheet privat baru dengan tab `Credentials`. Jangan memberi backend operasional atau pengguna mobile akses ke spreadsheet ini. Tambahkan Script Properties manual: pada Auth `AUTH_SPREADSHEET_ID`, `AUTH_SERVICE_SHARED_SECRET`, `LEGACY_USERS_SPREADSHEET_ID`, serta opsional `LEGACY_USERS_SHEET`; pada backend operasional `AUTH_SERVICE_URL` (URL `/exec` Auth) dan `AUTH_SERVICE_SHARED_SECRET` yang sama.

Generate secret acak minimal 32 karakter melalui password manager; jangan masukkan ke source, commit, log, atau command history. Setelah deployment, jalankan `setupAuthService()`, kemudian satu kali `migrateLegacyPlaintextPasswords_()` sebagai administrator Auth. Uji login beberapa akun aktif, hapus kolom `Password` dari spreadsheet operasional, hapus `LEGACY_USERS_SPREADSHEET_ID` dari Auth, lalu rotasi secret jika pernah terekspos. `resetCredential_(username, password)` adalah helper editor administrator, bukan endpoint publik; password minimal 12 karakter dan reset mencabut semua sesi melalui kenaikan `Auth Version`.

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
