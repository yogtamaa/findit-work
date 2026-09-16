# FindIt! Worker

Aplikasi Android internal petugas hotel untuk pencatatan barang temuan (lost & found) dengan bantuan AI. Aplikasi ini bagian dari ekosistem **FindIt!** — platform community-powered untuk mempertemukan barang hilang dengan pemiliknya.

---

## Fitur Utama

- **Login Petugas** — autentikasi email + password, token JWT disimpan aman (encrypted secure storage).
- **Quick Capture (AI)** — foto barang → AI otomatis mengisi nama, deskripsi, dan kategori barang dengan persentase akurasi (confidence). Hasil AI bisa diedit manual sebelum disimpan.
- **Form Pencatatan Lengkap** — isi manual nama barang, kategori, nomor kamar, waktu ditemukan, dan deskripsi.
- **Dashboard Riwayat** — daftar barang temuan milik petugas yang login, lengkap dengan filter status (Semua / Belum Diambil / Sudah Diambil).
- **Detail Barang** — lihat foto, kategori, lokasi, no. registrasi, dan deskripsi; tandai barang yang sudah diambil tamu.
- **Koneksi Aman** — semua request dienkripsi HTTPS, token JWT di kirim per-request, dan login menggunakan `flutter_secure_storage`.

---

## Teknologi

| Komponen | Teknologi |
|----------|-----------|
| Framework | Flutter (Dart) |
| State & Networking | dio (HTTP client + interceptor token) |
| Keamanan | flutter_secure_storage, JWT |
| Kamera/Galeri | image_picker |
| Backend | FindIt API (Laravel + analisis foto oleh AI) |

Backend live: `https://139-190-96-203.sslip.io/findit`

---

## Cara Install & Test di HP

### Opsi 1: Install APK langsung (cara mudah)

1. Minta file **`app-debug.apk`** (atau `app-release.apk`) dari rekan tim.
2. Kirim file ke HP Android (via WhatsApp / Bluetooth / kabel USB).
3. Buka file APK di HP → izinkan **"Install aplikasi tidak dikenal"** jika diminta.
4. Buka aplikasi **FindIt!** — logo khas FindIt, nama tampilan aplikasi di HP: **FindIt!**.

### Opsi 2: Build sendiri dari source

Persyaratan: Flutter SDK terinstall dan HP Android dalam mode Developer USB Debugging.

```bash
# 1. Install dependencies
flutter pub get

# 2. (Opsional) custom base URL backend
# flutter build apk --debug --dart-define=API_BASE_URL=https://your-domain.com/findit

# 3. Build APK debug
flutter build apk --debug

# 4. Install & run ke HP yang terhubung
flutter run -d <device-id>
```

Hasil build ada di: `build/app/outputs/flutter-apk/app-debug.apk`

> Catatan: APK debug butuh izin "Install aplikasi tidak dikenal" dan hanya cocok untuk pengujian. Untuk distribusi resmi, gunakan `flutter build apk --release` dengan signing config.

---

## Tutorial Penggunaan Aplikasi

### 1. Login

- Buka aplikasi → muncul halaman **Login Petugas**.
- Masukkan **email** dan **password** akun petugas (dibuatkan oleh Admin HR / Supervisor Front Office).
- Centang/isi **"Ingat Saya"** jika ingin tetap login tanpa input ulang saat aplikasi dibuka lagi (default: aktif).
  - **Ingat Saya AKTIF** → sesi disimpan permanen, buka aplikasi langsung masuk ke Dashboard.
  - **Ingat Saya NONAKTIF** → sesi hanya berlaku selama aplikasi terbuka; saat aplikasi ditutup, wajib login ulang.
- Tekan tombol **Masuk**.
- Lupa password? Hubungi admin di ekstensi 101/102 — reset hanya bisa dilakukan admin.

### 2. Dashboard

Setelah login kamu masuk ke **Dashboard** yang menampilkan:
- **Header** — logo FindIt!, nama hotel (Grand Meliá Jakarta), dan avatar profil (ketuk untuk membuka menu akun & logout).
- **Kartu "+ Catat Barang Temuan"** — tombol besar untuk mencatat temuan baru.
- **Filter riwayat** — tap untuk berpindah tampilan: `Semua`, `Belum Diambil`, `Sudah Diambil`.
- **Daftar barang temuan** — ketuk salah satu kartu untuk melihat detail.

### 3. Mencatat Barang Temuan (Quick Capture dengan AI)

1. Di dashboard, ketuk kartu **"+ Catat Barang Temuan"** atau tombol **+** di kanan bawah.
2. Ketuk area foto → pilih **"Ambil Foto"** (kamera) atau **"Pilih dari Galeri"**.
3. Foto otomatis dianalisis AI:
   - Ada panel **"Mengunggah foto X%…"** lalu **"Menganalisis foto…"**.
   - Hasil AI muncul sebagai **draf** (nama, kategori, deskripsi terisi otomatis).
   - Kalau akurasi rendah, muncul badge **"Hasil AI — Perlu dicek"** beserta persentase confidence.
4. **Periksa dan perbaiki** isian draft AI jika perlu — petugas bertanggung jawab atas akurasi data.
5. Lengkapi:
   - **Nama Barang** (wajib).
   - **Kategori** (pilih dari grid).
   - **Nomor Kamar** tempat barang ditemukan.
   - **Waktu ditemukan** (default: sekarang, bisa diubah).
   - **Deskripsi / Catatan tambahan** (opsional).
6. Tekan **"Simpan & Laporkan Temuan"**.
7. Muncul layar **sukses** berisi rincian temuan + nomor registrasi — barang tercatat.

> Gagal analisis AI karena jaringan lemah? Tidak masalah — isi form manual, foto akan tetap ter-upload saat disimpan.

### 4. Melihat Detail & Menandai Barang Diambil

- Ketuk kartu barang di dashboard → muncul bottom sheet **Detail** (foto, kategori, no. registrasi, lokasi, deskripsi).
- Barang yang belum diambil tamu menampilkan tombol hijau **"Tandai Sudah Diambil Tamu"**.
- Setelah ditandai, status berubah menjadi **"Barang sudah diambil tamu"** dan barang berpindah ke filter *Sudah Diambil*.

### 5. Logout

Ketuk **avatar** di pojok kiri header dashboard → pilih **Keluar / Logout**.

---

## Struktur Proyek

```
lib/
├── main.dart                        # Entry point aplikasi
├── core/
│   ├── network/                     # Dio client, ApiConfig (base URL), ApiException
│   └── security/                    # TokenStorage (JWT + user di secure storage)
└── features/
    ├── auth/                        # Login & pembuatan akun petugas
    │   ├── screens/                 # LoginScreen
    │   ├── widgets/                 # TextField, onboarding slide
    │   └── data/                    # AuthRepository, AuthUser
    └── worker/                      # Modul petugas (RA / Room Attendant)
        ├── screens/                 # Dashboard, Quick Report Form, Sukses
        ├── widgets/                 # Kartu temuan, filter, upload foto, dsb.
        ├── data/                    # ReportRepository (API barang temuan)
        ├── models/                  # FoundItem, Category, AutoFillResult
        ├── state/                   # FoundItemsController
        └── theme/                   # AppColors
```

---

## Environment & Konfigurasi

| Variabel | Deskripsi | Default |
|----------|-----------|---------|
| `API_BASE_URL` | Base URL backend FindIt | `https://139-190-96-203.sslip.io/findit` |

Contoh pakai base URL sendiri saat menjalankan:

```bash
flutter run --dart-define=API_BASE_URL=https://staging.findit.app/findit
```

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Aplikasi tidak bisa dibuka / besar sekali | Rilis terbaru APK; pastikan Android 7+ |
| Gagal memuat data di dashboard | Periksa koneksi internet, tekan **Muat Ulang** |
| Foto tidak teranalisis | Periksa izin kamera/storage & koneksi; isi manual sebagai cadangan |
| Login gagal | Pastikan email/password benar dan backend online |