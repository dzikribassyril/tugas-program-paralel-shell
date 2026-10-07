# Parallel Text Analyzer (Bash)

Analisis banyak file teks secara paralel dengan model *embarrassingly parallel* sesuai `lec-4_annotated.pdf` halaman 10–18. Tiap baris `hostfile` adalah satu worker. `localhost` menjalankan proses lokal di background; host lain menggunakan SSH noninteraktif dan membutuhkan direktori proyek bersama pada path yang sama.

## Menjalankan

Prasyarat: Bash, awk, GNU realpath, wc, date; SSH jika memakai host lain.

```bash
./generate_sample_data.sh 48 20000 input
./parallel_analyzer.sh input hostfile ERROR output/percobaan-baru
cat output/percobaan-baru/summary.tsv
```

Di GitHub data sintetis `input/` tidak diunggah karena berukuran 106 MB: perintah pertama di atas akan membuat ulang 48 file × 20.000 baris. Pada komputer tempat pengujian, `input/` sudah ada; lewati perintah pertama jika folder itu sudah tersedia. Generator menolak menimpa direktori lama, jadi untuk membuat data lain gunakan nama seperti `input-baru`.

Format perintah: `./parallel_analyzer.sh INPUT_DIR HOSTFILE KEYWORD OUTPUT_DIR`. Output harus merupakan direktori **baru** untuk setiap percobaan agar pengujian sebelumnya tidak tertimpa. `hostfile-1` memuat satu `localhost` untuk serial, `hostfile-2` dua, dan `hostfile` empat untuk paralel. File `.txt`/`.log` dalam direktori input (tidak rekursif) dibagi bergiliran berdasarkan urutan nama.

Hasil `details.tsv` berisi statistik per file, `worker-N.tsv` hasil masing-masing worker, `manifests/worker-N.txt` pembagian file, dan `summary.tsv` total. `matched_lines` adalah jumlah **baris** yang memuat keyword secara literal dan peka huruf besar/kecil. `bytes` mengasumsikan berkas teks dengan akhir baris LF; data generator memenuhi asumsi itu. Nama file dengan tab/newline tidak didukung.

Satu worker menulis hanya ke file keluarannya sendiri. Proses root menunggu seluruh PID worker (`wait`) dan memeriksa statusnya sebelum menggabungkan hasil, sehingga penulisan output tidak saling berebut. Jika memakai host lain, konfigurasi SSH key-based/passwordless dan shared filesystem terlebih dahulu; jangan menyimpan private key di folder proyek.

Lihat `laporan.md` untuk perintah pengujian, gambar cuplikan terminal yang dirender dari hasil asli di `screenshots/`, serta output nyata di `output/`. Gambar bisa dibuat ulang dengan `python3 render_screenshots.py` (opsional: membutuhkan Pillow).

## PDF laporan (A4)

PDF siap dikumpulkan: [`tugas_pararel_shell_140810230071.pdf`](tugas_pararel_shell_140810230071.pdf). Jika isi `laporan.md` berubah, buat ulang dengan Pandoc dan LuaLaTeX:

```bash
pandoc laporan.md --standalone --from gfm --lua-filter=pdf-pages.lua --include-in-header=pdf-style.tex --pdf-engine=lualatex -V papersize:a4 -V geometry:margin=20mm -V 'mainfont=DejaVu Sans' -V 'monofont=DejaVu Sans Mono' -V fontsize=10pt -V colorlinks=true -V urlcolor=blue --resource-path=. -o tugas_pararel_shell_140810230071.pdf
```
