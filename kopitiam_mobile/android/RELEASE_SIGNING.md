# Release signing Kopitiam

Package ID permanen: `id.co.uidbabel.kopitiam`.

## Aturan keamanan

`key.properties`, keystore, dan password **tidak boleh** masuk repository, issue, log CI, command history, atau artifact build. Simpan setiap nilai di password manager organisasi atau secret manager CI dengan akses minimum. `key.properties.example` hanya template tanpa secret.

## Membuat upload key baru

Jalankan dari `D:\Visual Studio Code\Kopitiam-UID-Babel\kopitiam_mobile\android` pada mesin rilis terkontrol:

```powershell
keytool -genkeypair -v -keystore app/kopitiam-release.jks -alias kopitiam -keyalg RSA -keysize 4096 -validity 10000
Copy-Item key.properties.example key.properties
```

Masukkan empat nilai asli pada `key.properties`: `storeFile`, `storePassword`, `keyAlias`, dan `keyPassword`. Pastikan keystore terenkripsi disimpan dalam vault yang disetujui dan recovery credential dibatasi untuk pengelola rilis.

Uji bundle release hanya pada mesin atau CI yang menyediakan secret tersebut:

```powershell
flutter build appbundle --release
```

CI pull request hanya membangun APK debug dan tidak menerima signing secret. Build release harus gagal bila file, property, atau keystore tidak tersedia.

## Insiden atau rotasi key

Keystore dan password yang pernah tersimpan dalam source atau Git history harus dianggap bocor: jangan gunakan lagi untuk rilis baru. Buat upload key baru, perbarui secret store, dan bila aplikasi sudah terdaftar di Google Play, ikuti prosedur **App integrity > App signing** di Play Console untuk mengganti upload key. Penggantian signing key distribusi mengikuti kebijakan Play App Signing dan harus dikoordinasikan dengan pemilik akun Play Console.

Hapus material lama dari branch aktif dan lakukan secret scanning. Penghapusan melalui commit baru tidak menghapus object dari history atau clone/fork yang telah ada; pemilik repository perlu menentukan rewrite history dan notifikasi insiden sesuai kebijakan organisasi.
