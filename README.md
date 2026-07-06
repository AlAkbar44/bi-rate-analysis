# 📊 BI Rate, Inflation, & Financial Indicators Analysis

Proyek ini dirancang untuk mengintegrasikan, memfilter, dan menganalisis data ekonomi makro Indonesia—khususnya interaksi antara **BI Rate (Suku Bunga Bank Indonesia)**, **tingkat inflasi (YoY)**, **nilai tukar rupiah (USD/IDR)**, dan **cadangan devisa**—menggunakan query SQL tingkat lanjut di DBeaver.

---

## 🚀 Fitur Utama & Penjelasan Kode

Berikut adalah urutan logika query SQL per fitur analisis yang digunakan dalam proyek ini:

### 🔍 1. Integrasi Seluruh Dataset (Full Dataset JOIN)
Fitur ini menggabungkan tabel dimensi waktu dengan seluruh tabel fakta indikator keuangan menggunakan pendekatan `LEFT JOIN` agar seluruh data sinkron berdasarkan ID periode[cite: 1].

<pre><code>
SELECT
    dw.periode, dw.tahun, dw.nama_bulan, dw.kuartal,
    br.bi_rate, k.kurs_usdidr_avg,
    inf.inflasi_yoy, cd.cadangan_devisa_miliar_usd
FROM dim_waktu dw
LEFT JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
LEFT JOIN fakta_kurs k ON dw.periode_id = k.periode_id
LEFT JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id
LEFT JOIN fakta_cadangan_devisa cd ON dw.periode_id = cd.periode_id
ORDER BY dw.periode;
</code></pre>

### 📈 2. Agregasi Rata-rata Indikator Tahunan
Fitur ini menghitung rata-rata tahunan dari suku bunga, nilai tukar, tingkat inflasi, dan cadangan devisa untuk melihat tren makro jangka panjang dengan pembulatan desimal yang rapi[cite: 1].

<pre><code>
SELECT
    dw.tahun,
    ROUND(AVG(br.bi_rate), 2)                   AS avg_bi_rate,
    ROUND(AVG(k.kurs_usdidr_avg), 0)             AS avg_kurs,
    ROUND(AVG(inf.inflasi_yoy), 2)               AS avg_inflasi,
    ROUND(AVG(cd.cadangan_devisa_miliar_usd), 1) AS avg_cadangan_devisa
FROM dim_waktu dw
LEFT JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
LEFT JOIN fakta_kurs k ON dw.periode_id = k.periode_id
LEFT JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id
LEFT JOIN fakta_cadangan_devisa cd ON dw.periode_id = cd.periode_id
GROUP BY dw.tahun
ORDER BY dw.tahun;
</code></pre>

### 🔄 3. Deteksi Arah Perubahan BI-Rate (Window Function LAG)
Menggunakan fungsi `LAG()` untuk membandingkan posisi suku bunga bulan berjalan dengan bulan sebelumnya guna mendeteksi momentum arah kebijakan moneter apakah naik, turun, atau tetap[cite: 1].

<pre><code>
WITH rate_seq AS (
    SELECT
        dw.periode, br.bi_rate,
        LAG(br.bi_rate) OVER (ORDER BY dw.periode) AS rate_bulan_lalu
    FROM dim_waktu dw
    JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
)
SELECT
    periode, bi_rate, rate_bulan_lalu,
    bi_rate - rate_bulan_lalu AS selisih,
    CASE
        WHEN bi_rate > rate_bulan_lalu THEN 'NAIK'
        WHEN bi_rate < rate_bulan_lalu THEN 'TURUN'
        ELSE 'TETAP'
    END AS arah_perubahan
FROM rate_seq
WHERE rate_bulan_lalu IS NOT NULL
  AND bi_rate <> rate_bulan_lalu
ORDER BY periode;
</code></pre>

### 📅 4. Event Study: Kurs Sebelum vs Sesudah Perubahan Rate
Analisis tingkat lanjut (*Event Study*) untuk mengevaluasi rata-rata pergerakan nilai tukar Rupiah pada jendela waktu 3 bulan sebelum dibandingkan dengan 3 bulan sesudah terjadinya perubahan BI Rate[cite: 1].

<pre><code>
WITH perubahan_rate AS (
    SELECT
        dw.periode, dw.periode_id, br.bi_rate,
        LAG(br.bi_rate) OVER (ORDER BY dw.periode) AS rate_sebelumnya
    FROM dim_waktu dw
    JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
),
event_dates AS (
    SELECT
        periode AS tanggal_event,
        periode_id AS event_periode_id,
        CASE WHEN bi_rate > rate_sebelumnya THEN 'NAIK' ELSE 'TURUN' END AS jenis_event
    FROM perubahan_rate
    WHERE rate_sebelumnya IS NOT NULL AND bi_rate <> rate_sebelumnya
)
SELECT
    e.tanggal_event, e.jenis_event,
    ROUND(AVG(CASE WHEN dw.periode_id BETWEEN e.event_periode_id - 3 AND e.event_periode_id - 1
               THEN k.kurs_usdidr_avg END), 0) AS kurs_avg_3bln_sebelum,
    ROUND(AVG(CASE WHEN dw.periode_id BETWEEN e.event_periode_id AND e.event_periode_id + 2
               THEN k.kurs_usdidr_avg END), 0) AS kurs_avg_3bln_sesudah
FROM event_dates e
JOIN dim_waktu dw ON dw.periode_id BETWEEN e.event_periode_id - 3 AND e.event_periode_id + 2
JOIN fakta_kurs k ON dw.periode_id = k.periode_id
GROUP BY e.tanggal_event, e.jenis_event
ORDER BY e.tanggal_event;
</code></pre>

### 🧮 5. Matriks Korelasi Statistik (CORR)
Mengukur kekuatan hubungan linear statistik antar indikator ekonomi makro menggunakan fungsi koefisien korelasi Pearson (`CORR`)[cite: 1].

<pre><code>
SELECT
    ROUND(CORR(br.bi_rate, k.kurs_usdidr_avg)::numeric, 3)      AS korelasi_rate_vs_kurs,
    ROUND(CORR(br.bi_rate, inf.inflasi_yoy)::numeric, 3)         AS korelasi_rate_vs_inflasi,
    ROUND(CORR(k.kurs_usdidr_avg, inf.inflasi_yoy)::numeric, 3)  AS korelasi_kurs_vs_inflasi
FROM dim_waktu dw
JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
JOIN fakta_kurs k ON dw.periode_id = k.periode_id
JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id;
</code></pre>

### 📉 6. Top 10 Depresiasi Kurs Bulanan Terbesar (MoM)
Mengidentifikasi 10 periode fluktuasi terburuk di mana mata uang Rupiah mengalami pelemahan (depresiasi) persentase bulanan tertinggi terhadap Dollar AS[cite: 1].

<pre><code>
WITH kurs_seq AS (
    SELECT
        dw.periode, k.kurs_usdidr_avg,
        LAG(k.kurs_usdidr_avg) OVER (ORDER BY dw.periode) AS kurs_bulan_lalu
    FROM dim_waktu dw
    JOIN fakta_kurs k ON dw.periode_id = k.periode_id
)
SELECT
    periode, kurs_usdidr_avg, kurs_bulan_lalu,
    ROUND(((kurs_usdidr_avg - kurs_bulan_lalu) / kurs_bulan_lalu * 100)::numeric, 2) AS depresiasi_persen_mom
FROM kurs_seq
WHERE kurs_bulan_lalu IS NOT NULL
ORDER BY depresiasi_persen_mom DESC
LIMIT 10;
```</pre>

### 💼 7. Studi Kasus Terbaru (Mei 2025 – Juni 2026)
Mengisolasi data historis teranyar untuk mengamati tren kebijakan moneter dan besar penurunan/intervensi cadangan devisa bulanan secara kontemporer[cite: 1].

<pre><code>
SELECT
    dw.periode, br.bi_rate, k.kurs_usdidr_avg,
    inf.inflasi_yoy, cd.cadangan_devisa_miliar_usd,
    LAG(cd.cadangan_devisa_miliar_usd) OVER (ORDER BY dw.periode) - cd.cadangan_devisa_miliar_usd
        AS penurunan_devisa_mom
FROM dim_waktu dw
LEFT JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
LEFT JOIN fakta_kurs k ON dw.periode_id = k.periode_id
LEFT JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id
LEFT JOIN fakta_cadangan_devisa cd ON dw.periode_id = cd.periode_id
WHERE dw.periode >= '2025-05-01'
ORDER BY dw.periode;
</code></pre>

### ⚡ 8. Ranking Volatilitas Kurs per Tahun (STDDEV)
Mengukur tingkat risiko volatilitas pasar valuta asing tahunan menggunakan fungsi Standar Deviasi (`STDDEV`), lengkap dengan pemetaan rentang nilai kurs terendah dan tertinggi[cite: 1].

<pre><code>
SELECT
    dw.tahun,
    ROUND(STDDEV(k.kurs_usdidr_avg)::numeric, 0) AS volatilitas_kurs,
    ROUND(MIN(k.kurs_usdidr_avg)::numeric, 0)    AS kurs_terendah,
    ROUND(MAX(k.kurs_usdidr_avg)::numeric, 0)    AS kurs_tertinggi
FROM dim_waktu dw
JOIN fakta_kurs k ON dw.periode_id = k.periode_id
GROUP BY dw.tahun
ORDER BY volatilitas_kurs DESC;
</code></pre>

---

## 📁 Struktur Folder & Aset
- `BI_query.sql` : Berkas utama tempat seluruh script query database disimpan[cite: 1].
- `data/` : Folder berisi berkas dataset mentah makroekonomi (.csv / .xlsx).
- `dashboard/` : Folder berisi file rancangan visualisasi interaktif / Tableau workbook.

---

## 🛠️ Cara Menggunakan Proyek Ini

1. **Clone Repositori ini:**
```bash
git clone https://github.com/AlAkbar44/Bi-Rate-Analysis.git
