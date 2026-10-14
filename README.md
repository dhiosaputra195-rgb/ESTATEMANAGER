# ESTATE MANAGER — Estate Management Golden Park

Aplikasi web satu file untuk manajemen estate/kegiatan perawatan **Golden Park @Serpong**.
Tidak butuh instalasi apa pun — cukup buka `index.html` di browser.

## Cara pakai

1. Buka `index.html` (klik dua kali).
2. Saat pertama dibuka, buat **akun admin** (nama, username, kata sandi min. 6 karakter).
3. Mulai tambahkan kegiatan.

## Fitur

| Menu | Isi |
|---|---|
| **Perencanaan** | Kegiatan per bulan & divisi, filter divisi, pencarian, subtotal biaya per divisi |
| **Progress** | Belum dikerjakan / Sedang dilakukan / Selesai, ubah status cepat, tombol "Bulan depan" untuk kegiatan rutin |
| **Dokumentasi** | Foto & lampiran dokumen (PDF/Word/dll) menempel pada pekerjaan |
| **Laporan Detail** | Tabel: No, Hari/Tanggal, Divisi, Aktivitas, Status, Vendor, PIC, Biaya, Keterangan + unduh PDF |
| **Laporan Summary** | Rekap per bulan: jumlah selesai / sedang / belum + total biaya + unduh PDF |
| **Pengguna** (admin) | Kelola akun Admin & Petugas |
| **Data** (admin) | Backup & restore seluruh data (JSON) + statistik penyimpanan |

### Detail tambahan
- **Divisi**: Administrasi, Keamanan, Teknisi (ME), Landscape, Kebersihan Sapuan, Maintenance Kolam Renang, Jasa Angkut Sampah.
- **Vendor / Kontraktor** dan **PIC / Penanggung jawab** per kegiatan.
- **Biaya (Rp)** per kegiatan, otomatis dijumlahkan di laporan.
- **Pencarian** pada menu Perencanaan, Progress, Laporan Detail, dan Summary.
- **Jadwal rutin bulanan**: salinan otomatis dibuat sampai bulan yang dipilih.
- **Lampiran dokumen**: unggah file (maks 5 MB per file) yang menempel pada pekerjaan.
- **Backup / Impor**: unduh daftar kegiatan & pengguna (JSON), lalu impor kembali kapan saja.
- Mode **terang/gelap** otomatis, tampilan responsif HP & desktop.
- Export laporan ke **PDF** (dengan logo & tanda tangan waktu cetak).

## Penyimpanan data

Semua data disimpan terpusat di **Supabase**:

| Data | Tempat |
|---|---|
| Akun pengguna (admin/petugas) | tabel `public.users` (kata sandi di-hash bcrypt, hanya lewat fungsi RPC) |
| Pekerjaan / kegiatan | tabel `public.activities` |
| Foto dokumentasi | tabel `public.photos` + **Supabase Storage** (`estate/foto/...`) |
| Lampiran dokumen | tabel `public.docs` + **Supabase Storage** (`estate/lampiran/...`) |

Karena tersimpan di server, data bisa dibuka dari perangkat mana pun dengan akun yang sama.

## Setup Supabase

1. Buat project di https://supabase.com (gratis).
2. Buka **SQL Editor → New query**, tempel isi `supabase-schema.sql`, lalu **Run**.
   Ini membuat tabel, fungsi login, dan bucket Storage `estate`.
3. Buka **Project Settings → API**, salin:
   - **Project URL** → `SB_URL`
   - **anon public** key → `SB_KEY`
4. Buka `index.html`, cari dua baris di bagian atas script dan isi nilainya:

   ```js
   const SB_URL = 'https://xxxx.supabase.co';
   const SB_KEY = 'eyJhbGciOi...';
   ```
5. Simpan, buka `index.html` di browser. Saat pertama kali, buat **akun admin**.

> **Catatan keamanan:** aplikasi ini memakai *anon key* + akses terbuka (RLS `using(true)`) untuk
> kesederhanaan. Cocok untuk pemakaian internal. Untuk keamanan lebih ketat, gunakan Supabase Auth
> dan perketat policy RLS.

## Backup

Menu **Data → Unduh backup** mengunduh daftar kegiatan & pengguna (JSON). Menu **Impor** menambahkan
kegiatan dari file backup ke database (media/foto tidak ikut dipindahkan).

## Teknologi

HTML + CSS + JavaScript murni (tanpa build). Data & login lewat **Supabase** (`@supabase/supabase-js`), PDF memakai jsPDF & jsPDF-AutoTable dari CDN.

## Struktur

```
index.html            # seluruh aplikasi (UI, logika, koneksi Supabase)
supabase-schema.sql   # skema database + storage + fungsi login (jalankan sekali)
README.md             # dokumen ini
```
