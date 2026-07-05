#Full Dataset JOIN
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

#Rata_rata Tahunan
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

#Deteksi Perubahan BI-Rate (Window Function LAG)
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

#Event Study: Kurs 3 Bulan Sebelum vs Sesudah Perubahan Rate
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

#Korelasi (CORR)
SELECT
    ROUND(CORR(br.bi_rate, k.kurs_usdidr_avg)::numeric, 3)      AS korelasi_rate_vs_kurs,
    ROUND(CORR(br.bi_rate, inf.inflasi_yoy)::numeric, 3)         AS korelasi_rate_vs_inflasi,
    ROUND(CORR(k.kurs_usdidr_avg, inf.inflasi_yoy)::numeric, 3)  AS korelasi_kurs_vs_inflasi
FROM dim_waktu dw
JOIN fakta_bi_rate br ON dw.periode_id = br.periode_id
JOIN fakta_kurs k ON dw.periode_id = k.periode_id
JOIN fakta_inflasi inf ON dw.periode_id = inf.periode_id;

#Top 10 Depresiasi Bulanan Terbesar (MoM)
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

#Studi Kasus Terbaru: Mei 2025 – Jun 2026
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

#Ranking Volatilitas Kurs per Tahun (STDDEV)
SELECT
    dw.tahun,
    ROUND(STDDEV(k.kurs_usdidr_avg)::numeric, 0) AS volatilitas_kurs,
    ROUND(MIN(k.kurs_usdidr_avg)::numeric, 0)    AS kurs_terendah,
    ROUND(MAX(k.kurs_usdidr_avg)::numeric, 0)    AS kurs_tertinggi
FROM dim_waktu dw
JOIN fakta_kurs k ON dw.periode_id = k.periode_id
GROUP BY dw.tahun
ORDER BY volatilitas_kurs DESC;