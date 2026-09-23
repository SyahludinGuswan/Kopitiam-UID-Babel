# Audit dan Progress Penguatan Sistem Kopitiam

**Diperbarui:** 23 September 2026  
**Repository:** `SyahludinGuswan/Kopitiam-UID-Babel`  
**Status umum:** penguatan source dan CI berjalan bertahap; deployment serta verifikasi produksi belum dilakukan.

## Prinsip status

- **Selesai di source** berarti implementasi sudah masuk `main` dan check relevan lulus.
- **Terverifikasi produksi** memerlukan provisioning, deployment, data migration, dan uji operasional nyata. Status ini belum diberikan untuk audit mana pun di bawah.
- Scope Kopitiam adalah **internal-only**; tidak ada upload ke Play Store.
- Secret, signing key, spreadsheet privat, dan HMAC production tidak disimpan di repository atau chat.

## Selesai di source

| ID | Status | Bukti | Catatan |
|---|---|---|---|
| SEC-04 | Selesai di source/CI | Signing APK internal fail-closed; `ci/check-android-signing.cjs`; PR #4 merged; local regression 3/3 lulus | Key lama pernah masuk history dan dianggap bocor. Key baru cocok dengan APK. Instalasi perangkat nyata dilewati dan tetap tercatat belum diverifikasi. |
| SEC-07 | Selesai di source | `LocalAccountStorage`; namespace SHA-256 per username; database, foto, cache, dan antrean memakai namespace akun; test isolasi tersedia | Uji pergantian akun pada perangkat nyata masih wajib sebelum production-ready. |
| SEC-08 | Selesai di source | PR #2 merged | Policy assignment, immutable fields, dan transisi status WO sudah diuji. |
| SEC-10 | Selesai di source | PR #1 merged | Identitas Temuan dan ownership record existing dilindungi saat retry/overwrite. |
| SEC-11 | Selesai di source | PR #3 merged melalui commit `19b9ace` | Tier, Temuan canonical, Prioritas, dan relasi aset diturunkan dari master pusat. |
| REL-03 | Selesai di source/CI | PR #7 merged melalui commit `f56e7ae`; external `REVISION_INDEX`, `REVISION_AUDIT`, stable key, conflict check, lock, dan sparse-write | Tidak menambah kolom fisik pada business sheet. Read tetap kompatibel sebelum metadata diprovision; write fail-closed sampai `REVISION_METADATA_SPREADSHEET_ID` dikonfigurasi. |

## Selesai di source, validasi operasional pending

| ID | Status | Bukti | Blocker |
|---|---|---|---|
| SEC-05 | Source/test selesai | `flutter_secure_storage` untuk token, profil, password hash, salt, dan offline status; `allowBackup=false`; offline lease 24 jam; test secure session dan account guard lulus | Uji perangkat nyata: migrasi sesi lama, logout, expiry, restart, pergantian akun, backup/restore, dan jaringan buruk. |
| SEC-06 | Source/CI selesai | Auth terpisah dengan PBKDF2-HMAC-SHA-256, token opaque, introspection/revoke, replay protection, HMAC envelope; PR #5 merged; Auth regression 4/4 dan CI hijau | Provisioning Auth spreadsheet, `AUTH_SERVICE_SHARED_SECRET`, migrasi plaintext, penghapusan kolom `Password`, recovery, dan rotasi HMAC production. |

## Audit berikutnya

1. **P2 hardening:** validasi JPEG, pembatasan master data, pemrosesan foto, permission iOS, dan release hardening.
2. **Validasi operasional:** perangkat nyata, jaringan buruk, restart, pergantian akun, fault injection staging, backup/restore, ACL, logging, dan rollback.

## Aturan produksi

Sebelum production sign-off, lakukan backup dan dry run/staging untuk setiap migrasi. Rekonsiliasi jumlah akun sebelum menghapus kolom plaintext. Provisioning secret dilakukan melalui secret manager, bukan commit atau chat. Setiap perubahan production harus punya bukti deployment, hasil uji, dan rencana rollback.

## Aturan pembaruan dokumen

Setiap temuan hanya diberi status **selesai di source** setelah perubahan masuk `main`, CI relevan lulus, dan diff final diaudit. Status **terverifikasi produksi** hanya boleh diberikan setelah deployment dan uji operasional aktual tercatat.
