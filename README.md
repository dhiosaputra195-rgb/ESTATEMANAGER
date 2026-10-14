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
- **Lampiran dokumen**: unggah file (maks 2 MB per file) yang menempel pada pekerjaan.
- **Backup / Restore**: unduh seluruh data (termasuk foto & lampiran) ke satu file JSON, lalu pulihkan kapan saja.
- Mode **terang/gelap** otomatis, tampilan responsif HP & desktop.
- Export laporan ke **PDF** (dengan logo & tanda tangan waktu cetak).

## Penyimpanan data

Data disimpan di **localStorage browser** (per perangkat/per browser).
Gunakan menu **Data → Unduh backup** secara berkala agar data tidak hilang bila cache browser dibersihkan.

## Teknologi

HTML + CSS + JavaScript murni (tanpa build). PDF memakai jsPDF & jsPDF-AutoTable dari CDN.

## Struktur

```
index.html   # seluruh aplikasi (UI, logika, penyimpanan)
README.md    # dokumen ini
```
